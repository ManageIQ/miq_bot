require 'spec_helper'

describe CommitMonitorHandlers::Batch::GithubPrCommenter::MigrationDateChecker do
  let(:commits_list)   { ["123abc", "234def"] }
  let(:diff_file_names_params) { ["origin/master", commits_list.last] }
  let(:branch)         { create(:pr_branch, :commits_list => commits_list) }
  let(:batch_entry)    { BatchEntry.create!(:job => BatchJob.create!) }
  let(:git_service)    { stub_git_service }

  before do
    stub_sidekiq_logger
    stub_job_completion
  end

  it "with bad migration dates" do
    expect(git_service).to receive(:diff_file_names).with(*diff_file_names_params).and_return([
      "db/migrate/20151435234623_do_some_stuff.rb", # bad
      "db/migrate/20150821123456_do_some_stuff.rb", # good
      "blah.rb"                                     # ignored
    ])

    described_class.new.perform(batch_entry.id, branch.id, nil)

    batch_entry.reload
    expect(batch_entry.result).to     include("Bad migration date:")
    expect(batch_entry.result).to     include("20151435234623")
    expect(batch_entry.result).to_not include("20150821123456")
  end

  it "with multiple bad migration dates" do
    expect(git_service).to receive(:diff_file_names).with(*diff_file_names_params).and_return([
      "db/migrate/20151435234623_do_some_stuff.rb", # bad
      "db/migrate/20151435234624_do_some_stuff.rb", # bad
      "db/migrate/20150821123456_do_some_stuff.rb", # good
      "blah.rb"                                     # ignored
    ])

    described_class.new.perform(batch_entry.id, branch.id, nil)

    batch_entry.reload
    expect(batch_entry.result).to     include("Bad migration dates:")
    expect(batch_entry.result).to     include("20151435234623")
    expect(batch_entry.result).to     include("20151435234624")
    expect(batch_entry.result).to_not include("20150821123456")
  end

  it "with no bad migration dates" do
    expect(git_service).to receive(:diff_file_names).with(*diff_file_names_params).and_return([
      "db/migrate/20150821123456_do_some_stuff.rb", # good
      "blah.rb"                                     # ignored
    ])

    described_class.new.perform(batch_entry.id, branch.id, nil)

    expect(batch_entry.reload.result).to be_nil
  end

  it "with no migrations" do
    expect(git_service).to receive(:diff_file_names).with(*diff_file_names_params).and_return([
      "blah.rb" # ignored
    ])

    described_class.new.perform(batch_entry.id, branch.id, nil)

    expect(batch_entry.reload.result).to be_nil
  end
end
