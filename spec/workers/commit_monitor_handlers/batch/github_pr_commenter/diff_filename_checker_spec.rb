require 'spec_helper'

describe CommitMonitorHandlers::Batch::GithubPrCommenter::DiffFilenameChecker do
  let(:batch_entry)        { BatchEntry.create!(:job => BatchJob.create!) }
  let(:branch)             { create(:pr_branch) }
  let(:diff)               { double("RuggedDiff", :new_files => new_files) }
  let(:git_service_double) { double("GitService", :diff => diff) }
  let(:github_service)     { stub_github_service }

  before do
    stub_sidekiq_logger
    stub_job_completion
    stub_settings(:gemfile_checker, :pr_contacts, [])
    stub_settings(:gemfile_checker, :enabled_repos, [branch.repo.name])
    github_service
    expect_any_instance_of(Branch).to receive(:git_service).and_return(git_service_double)
  end

  context "Gemfile Checker" do
    context "when there are Gemfile changes" do
      context "adds a label to the PR" do
        let(:new_files) { ["Gemfile"] }
        before do
          expect(github_service).to receive(:add_issue_labels).with(branch.pr_number, "gem changes")
        end

        it "and adds a comment to the batch" do
          described_class.new.perform(batch_entry.id, branch.id, nil)

          result = batch_entry.reload.result
          expect(result.length).to eq(1)
          expect(result.first.to_s).to eq("- [ ] :grey_exclamation: - Gemfile changes detected.")
        end

        it "and adds a comment to the batch with PR contacts" do
          stub_settings(:gemfile_checker, :pr_contacts, %w(@user1 @user2))

          described_class.new.perform(batch_entry.id, branch.id, nil)

          result = batch_entry.reload.result
          expect(result.length).to eq(1)
          expect(result.first.to_s).to eq("- [ ] :grey_exclamation: - Gemfile changes detected. /cc @user1 @user2")
        end
      end
    end

    context "where there are no Gemfile changes" do
      let(:new_files) { [] }

      it "does not add a label to the PR" do
        expect(github_service).to_not receive(:add_issue_labels)

        described_class.new.perform(batch_entry.id, branch.id, nil)
      end

      it "does not add a comment to the batch" do
        described_class.new.perform(batch_entry.id, branch.id, nil)

        expect(batch_entry.reload.result).to eq([])
      end
    end
  end

  context "Migration Timestamp" do
    context "with bad migration dates" do
      let(:new_files) do
        [
          "db/migrate/20151435234623_do_some_stuff.rb", # bad
          "db/migrate/20150821123456_do_some_stuff.rb", # good
          "blah.rb"                                     # ignored
        ]
      end

      it "with one bad, one good, one ignored" do
        described_class.new.perform(batch_entry.id, branch.id, nil)

        batch_entry.reload
        expect(batch_entry.result.length).to eq(1)
        expect(batch_entry.result.first).to have_attributes(:group => "db/migrate/20151435234623_do_some_stuff.rb", :message => "Bad Migration Timestamp")
      end
    end

    context "with multiple bad migration dates" do
      let(:new_files) do
        [
          "db/migrate/20151435234623_do_some_stuff.rb", # bad
          "db/migrate/20151435234624_do_some_stuff.rb", # bad
          "db/migrate/20150821123456_do_some_stuff.rb", # good
          "blah.rb"                                     # ignored
        ]
      end

      it "with two bad, one good, one ignored" do
        described_class.new.perform(batch_entry.id, branch.id, nil)

        batch_entry.reload
        expect(batch_entry.result.length).to eq(2)
        results = batch_entry.result.sort!
        expect(results.first).to have_attributes(:group => "db/migrate/20151435234623_do_some_stuff.rb", :message => "Bad Migration Timestamp")
        expect(results.last).to have_attributes(:group => "db/migrate/20151435234624_do_some_stuff.rb", :message => "Bad Migration Timestamp")
      end
    end

    context "with no bad migration dates" do
      let(:new_files) do
        [
          "db/migrate/20150821123456_do_some_stuff.rb", # good
          "blah.rb"                                     # ignored
        ]
      end

      it "one good, one ignored" do
        described_class.new.perform(batch_entry.id, branch.id, nil)

        expect(batch_entry.reload.result).to eq([])
      end
    end

    context "with no migrations" do
      let(:new_files) do
        [
          "blah.rb" # ignored
        ]
      end

      it "one ignored" do
        described_class.new.perform(batch_entry.id, branch.id, nil)

        expect(batch_entry.reload.result).to eq([])
      end
    end
  end
end
