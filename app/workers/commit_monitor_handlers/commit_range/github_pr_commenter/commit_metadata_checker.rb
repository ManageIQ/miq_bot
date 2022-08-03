require 'rugged'

module CommitMonitorHandlers::CommitRange
  class GithubPrCommenter::CommitMetadataChecker
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot_glacial

    include BatchEntryWorkerMixin
    include BranchWorkerMixin

    def perform(batch_entry_id, branch_id, new_commits)
      return unless find_batch_entry(batch_entry_id)
      return skip_batch_entry unless find_branch(branch_id, :pr)

      complete_batch_entry(:result => process_commits(new_commits))
    end

    private

    def process_commits(new_commits)
      @offenses = []

      new_commits.each do |commit_sha, data|
        check_for_usernames_in(commit_sha, data["message"])
        check_for_merge_commit(commit_sha, data["merge_commit?"])
      end

      @offenses
    end

    # From https://github.com/join
    #
    #     "Username may only contain alphanumeric characters or single hyphens,
    #     and cannot begin or end with a hyphen."
    #
    # To check for the start of a username we do a positive lookbehind to get
    # the `@` (but only if it is surrounded by whitespace), and a positive
    # lookhead at the end to confirm there is a whitespace char following the
    # "var" (isn't an instance variable with a trailing `.`, has an `_`, or is
    # actually an email address)
    #
    # Since there can't be underscores in Github usernames, this makes it so we
    # rule out partial matches of variables (@database_records having a
    # username lookup of `database`), but still catch full variable names
    # without underscores (`@foobarbaz`).
    #
    USERNAME_REGEXP = /
      (?<=^@|\s@)     # must start with a '@' (don't capture)
      [a-zA-Z0-9]     # first character must be alphanumeric
      [a-zA-Z0-9\-]*  # middle chars may be alphanumeric or hyphens
      [a-zA-Z0-9]     # last character must be alphanumeric
      (?=[\s])        # allow only variables without "_" (not captured)
    /x.freeze

    def check_for_usernames_in(commit, message)
      message.scan(USERNAME_REGEXP).each do |potential_username|
        next unless GithubService.username_lookup(potential_username)

        group   = ::Branch.github_commit_uri(fq_repo_name, commit)
        message = "Username `@#{potential_username}` detected in commit message. Consider removing."
        @offenses << OffenseMessage::Entry.new(:low, message, group)
      end
    end

    def check_for_merge_commit(commit, merge_commit)
      return unless merge_commit

      group   = ::Branch.github_commit_uri(fq_repo_name, commit)
      message = "Merge commit #{commit} detected.  Consider rebasing."
      @offenses << OffenseMessage::Entry.new(:low, message, group)
    end
  end
end
