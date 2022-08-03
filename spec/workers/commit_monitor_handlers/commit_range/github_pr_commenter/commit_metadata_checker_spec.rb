describe CommitMonitorHandlers::CommitRange::GithubPrCommenter::CommitMetadataChecker do
  let(:batch_entry)        { BatchEntry.create!(:job => BatchJob.create!) }
  let(:branch)             { create(:pr_branch) }
  let(:commit_message_1)   { "Adds SUPER FEATURE.  BREAKS NOTHING!" }
  let(:commit_message_2)   { "fix tests" }
  let(:commit_message_3)   { "fix moar tests" }
  let(:merge_commit_1)     { false }
  let(:merge_commit_2)     { false }
  let(:merge_commit_3)     { false }

  let(:commits) do
    {
      "abcd123" => {"message" => commit_message_1, "files" => ["app/models/super.rb"],        "merge_commit?" => merge_commit_1},
      "abcd234" => {"message" => commit_message_2, "files" => ["spec/models/super_spec.rb"],  "merge_commit?" => merge_commit_2},
      "abcd345" => {"message" => commit_message_3, "files" => ["spec/models/normal_spec.rb"], "merge_commit?" => merge_commit_3}
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
            @database_records.to_a

        Avoids a N+1 on authors by adding an .includes call

            @booksandauthors = Books.all.includes(:author)

        Saving us 100s of queries for our tiny bookstore app.

        Thanks to @Fryguy and @Nick-LaMuro for this suggestion!
      COMMIT_MSG
    end

    # Note:  `@dbrecords` in this message are all cases that will not get
    # picked up as a username in this example.
    let(:commit_message_2) do
      <<~COMMIT_MSG
        fixes tests

        Forgot that we stubbed things...

        `expect(@dbrecords).to ...` not `any_instance_of(ActiveRecord).to ...`

        Assign it as a variable by doing `@dbrecords = %w[foo bar]`

        cc @Fryguy @NickLaMuro
      COMMIT_MSG
    end

    let(:commit_message_3) do
      <<~COMMIT_MSG
        fixes moar tests

        I forget how to rebase... #dealWithIt @NickLaMura

        Original commit by nicklamuro@example.com
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

  context "with merge commits" do
    let(:merge_commit_1) { true }
    let(:merge_commit_2) { true }
    let(:merge_commit_3) { false }

    it "returns one offense for each merge commit" do
      described_class.new.perform(batch_entry.id, branch.id, commits)

      batch_entry.reload
      expect(batch_entry.result.length).to eq(2)
      expect(batch_entry.result.first).to have_attributes(
        :group   => "https://github.com/#{branch.fq_repo_name}/commit/abcd123",
        :message => "Merge commit abcd123 detected.  Consider rebasing."
      )
      expect(batch_entry.result.second).to have_attributes(
        :group   => "https://github.com/#{branch.fq_repo_name}/commit/abcd234",
        :message => "Merge commit abcd234 detected.  Consider rebasing."
      )
    end
  end
end
