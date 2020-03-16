describe CommitMonitorHandlers::CommitRange::GithubPrCommenter::CommitMetadataChecker do
  let(:batch_entry)        { BatchEntry.create!(:job => BatchJob.create!) }
  let(:branch)             { create(:pr_branch) }
  let(:commit_message_1)   { "Adds SUPER FEATURE.  BREAKS NOTHING!" }
  let(:commit_message_2)   { "fix tests" }
  let(:commit_message_3)   { "fix moar tests" }

  let(:commits) do
    {
      "abcd123" => {"message" => commit_message_1, "files" => ["app/models/super.rb"]},
      "abcd234" => {"message" => commit_message_2, "files" => ["spec/models/super_spec.rb"]},
      "abcd345" => {"message" => commit_message_3, "files" => ["spec/models/normal_spec.rb"]}
    }
  end

  let(:username_lookup_cache) do
    {
      "Fryguy"          => 123, # valid user
      "NickLaMuro"      => 234, # valid user
      "NickLaMura"      => nil, # mispelled invalid user
      "Nick-LaMuro"     => nil, # invalid user with hyphen
      "booksandauthors" => nil  # not a user (surprisingly)
    }
  end

  before do
    stub_sidekiq_logger
    stub_job_completion

    allow(GithubService).to receive(:username_lookup_cache).and_return(username_lookup_cache)
  end

  context "with basic commit messages" do
    it "doesn't create any offenses" do
      described_class.new.perform(batch_entry.id, branch.id, commits)

      batch_entry.reload
      expect(batch_entry.result.length).to eq(0)
    end
  end

  context "with multiline commit messages" do
    let(:commit_message_1) do
      <<~COMMIT_MSG
        In which the hero adds the greatest feature...

        With this change, I made it so that by changing this:

            @database_records = Books.all

        Avoids a N+1 on authors by adding an .includes call

            @booksandauthors = Books.all.includes(:author)

        Saving us 100s of queries for our tiny bookstore app.

        Thanks to @Fryguy and @Nick-LaMuro for this suggestion!
      COMMIT_MSG
    end

    let(:commit_message_2) do
      <<~COMMIT_MSG
        fixes tests

        Forgot that we stubbed things...

        cc @Fryguy @NickLaMuro
      COMMIT_MSG
    end

    let(:commit_message_3) do
      <<~COMMIT_MSG
        fixes moar tests

        I forget how to rebase... #dealWithIt @NickLaMura
      COMMIT_MSG
    end

    it "returns one offense for each valid username" do
      described_class.new.perform(batch_entry.id, branch.id, commits)

      batch_entry.reload
      expect(batch_entry.result.length).to eq(3)
      expect(batch_entry.result.first).to have_attributes(
        :group   => "https://github.com/#{branch.fq_repo_name}/commit/abcd123",
        :message => "Username `@Fryguy` detected in commit message. Consider removing."
      )
      expect(batch_entry.result.second).to have_attributes(
        :group   => "https://github.com/#{branch.fq_repo_name}/commit/abcd234",
        :message => "Username `@Fryguy` detected in commit message. Consider removing."
      )
      expect(batch_entry.result.third).to have_attributes(
        :group   => "https://github.com/#{branch.fq_repo_name}/commit/abcd234",
        :message => "Username `@NickLaMuro` detected in commit message. Consider removing."
      )
    end
  end
end
