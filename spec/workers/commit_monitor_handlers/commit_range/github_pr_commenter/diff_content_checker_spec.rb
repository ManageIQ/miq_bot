require 'rails_helper'

describe CommitMonitorHandlers::CommitRange::GithubPrCommenter::DiffContentChecker do
  let(:batch_entry)        { BatchEntry.create!(:job => BatchJob.create!) }
  let(:branch)             { create(:pr_branch) }
  let(:content_1)          { "def a(variable)" }
  let(:content_2)          { "# this is going to `puts` 'hi'" }
  let(:content_3)          { "puts 'hi'" }
  let(:file_path)          { "tools/abc.rb" }
  let(:git_service_double) { double("GitService", :diff => diff) }

  let(:diff) do
    rugged_delta  = double("RuggedDelta", :new_file => {:path => file_path})
    rugged_line_1 = double("RuggedLine",  :addition? => true, :content => content_1, :new_lineno => 1)
    rugged_line_2 = double("RuggedLine",  :addition? => true, :content => content_2, :new_lineno => 2)
    rugged_line_3 = double("RuggedLine",  :addition? => true, :content => content_3, :new_lineno => 3)
    rugged_hunk   = double("RuggedHunk",  :lines => [rugged_line_1, rugged_line_2, rugged_line_3])
    rugged_patch  = double("RuggedPatch", :hunks => [rugged_hunk], :delta => rugged_delta)
    rugged_diff   = double("RuggedDiff",  :patches => [rugged_patch])
    GitService::Diff.new(rugged_diff)
  end

  before do
    stub_sidekiq_logger
    stub_job_completion
    expect_any_instance_of(Branch).to receive(:git_service).and_return(git_service_double)
  end

  context "with offending word" do
    it "with one offender in the diff" do
      stub_settings(:diff_content_checker => {"offenses" => {"puts" => {:severity => :error}}})
      described_class.new.perform(batch_entry.id, branch.id, nil)

      batch_entry.reload
      expect(batch_entry.result.length).to eq(2)
      expect(batch_entry.result.first).to have_attributes(
        :group   => file_path,
        :locator => 2,
        :message => "Detected `puts`"
      )
      expect(batch_entry.result.last).to have_attributes(
        :group   => file_path,
        :locator => 3,
        :message => "Detected `puts`"
      )
    end

    it "with one offender in the diff of an ignored file" do
      stub_settings(:diff_content_checker => {"offenses" => {"puts" => {:except => ["tools/"], :severity => :error}}})
      described_class.new.perform(batch_entry.id, branch.id, nil)

      batch_entry.reload
      expect(batch_entry.result.length).to eq(0)
    end

    context "where the offender is part of another word in the diff" do
      let(:content_2) { "# this is going to display 'hi'" }
      let(:content_3) { "inputs = variable" }

      it do
        stub_settings(:diff_content_checker => {"offenses" => {"puts" => {:severity => :error}}})
        described_class.new.perform(batch_entry.id, branch.id, nil)

        batch_entry.reload
        expect(batch_entry.result.length).to eq(0)
      end
    end
  end

  context "with offending regex" do
    it "with one offender in the diff" do
      stub_settings(:diff_content_checker => {"offenses" => {"^([^#]+|)\\bputs\\b" => {:severity => :error, :type => :regexp, :message => "Detected `puts`"}}})
      described_class.new.perform(batch_entry.id, branch.id, nil)

      batch_entry.reload
      expect(batch_entry.result.length).to eq(1)
      expect(batch_entry.result.first).to have_attributes(
        :group   => file_path,
        :locator => 3,
        :message => "Detected `puts`"
      )
    end
  end
end
