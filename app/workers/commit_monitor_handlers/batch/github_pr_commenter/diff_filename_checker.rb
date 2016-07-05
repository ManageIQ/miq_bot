module CommitMonitorHandlers::Batch
  class GithubPrCommenter::DiffFilenameChecker
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot_glacial

    include BatchEntryWorkerMixin
    include BranchWorkerMixin

    def perform(batch_entry_id, branch_id, _new_commits)
      return unless find_batch_entry(batch_entry_id)
      return unless find_branch(branch_id, :pr)
      complete_batch_entry(:result => process_files)
    end

    private

    def process_files
      @offenses = []
      @tags = []

      branch.git_service.diff.new_files.each do |file|
        check_for_gemfile_changes(file)
        validate_migration_timestamp(file)
      end

      apply_tags

      @offenses
    end

    def check_for_gemfile_changes(file)
      return unless File.basename(file) == "Gemfile"

      contacts = Settings.gemfile_checker.pr_contacts.join(" ")
      message = "Gemfile changes detected."
      message << " /cc #{contacts}" unless contacts.blank?

      @offenses << OffenseMessage::Entry.new(:low, message, file)
      @tags |= ["gem changes"]
    end

    def validate_migration_timestamp(file)
      return unless file.include?("db/migrate/")
      ts = File.basename(file).split("_").first
      return if valid_timestamp?(ts)

      @offenses << OffenseMessage::Entry.new(:error, "Bad Migration Timestamp", file)
    end

    def valid_timestamp?(ts)
      Time.parse(ts)
    rescue ArgumentError
      false
    end

    def apply_tags
      branch.repo.with_github_service do |github|
        @tags.each do |tag|
          logger.info("Updating PR #{pr_number} with label #{tag.inspect}.")
          github.add_issue_labels(pr_number, tag)
        end
      end
    end
  end
end
