module CommitMonitorHandlers::Batch
  class GithubPrCommenter::GemfileChecker
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot

    include BatchEntryWorkerMixin
    include BranchWorkerMixin

    LABEL_NAME = "gem changes".freeze

    def perform(batch_entry_id, branch_id, _new_commits)
      return unless find_batch_entry(batch_entry_id)
      return unless find_branch(branch_id, :pr)
      return unless verify_branch_enabled

      if gemfile_in_diff?
        add_pr_label
        batch_entry_changes = {:result => new_comment}
      else
        batch_entry_changes = {}
      end
      complete_batch_entry(batch_entry_changes)
    end

    private

    def add_pr_label
      logger.info("Updating PR #{pr_number} with label #{LABEL_NAME.inspect}.")
      branch.repo.with_github_service do |github|
        github.add_issue_labels(pr_number, LABEL_NAME)
      end
    end

    def new_comment
      message = "Gemfile changes detected."

      contacts = Settings.gemfile_checker.pr_contacts.join(" ")
      message << " /cc #{contacts}" unless contacts.blank?

      message
    end

    def gemfile_in_diff?
      return @gemfile_in_diff unless @gemfile_in_diff.nil?
      @gemfile_in_diff = diff_file_names_for_merge.any? do |f|
        File.basename(f) == "Gemfile"
      end
    end
  end
end
