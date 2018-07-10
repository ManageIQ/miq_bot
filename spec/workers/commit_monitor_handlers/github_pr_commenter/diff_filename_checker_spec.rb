describe CommitMonitorHandlers::GithubPrCommenter::DiffFilenameChecker do
  let(:batch_entry) { BatchEntry.create!(:job => BatchJob.create!) }
  let(:branch)      { create(:pr_branch) }
  let(:git_service) { double("GitService", :diff => double("RuggedDiff", :new_files => new_files)) }

  before do
    stub_sidekiq_logger
    stub_job_completion
    expect_any_instance_of(Branch).to receive(:git_service).and_return(git_service)
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
