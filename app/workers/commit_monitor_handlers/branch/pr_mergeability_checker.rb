class CommitMonitorHandlers::Branch::PrMergeabilityChecker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot_glacial

  include BranchWorkerMixin

  LABEL = "unmergeable".freeze

  def self.handled_branch_modes
    [:pr]
  end

  def perform(branch_id)
    return unless find_branch(branch_id, :pr)

    process_mergeability
  end

  private

  def tag
    "<pr-mergeability-checker />"
  end

  def process_mergeability
    was_mergeable       = branch.mergeable?
    currently_mergeable = branch.git_service.mergeable?

    if was_mergeable && !currently_mergeable
      write_to_github
      apply_label
    elsif !was_mergeable && currently_mergeable
      remove_label
    end

    # Update columns directly to avoid collisions wrt the serialized column issue
    branch.update_columns(:mergeable => currently_mergeable)
  end

  def write_to_github
    logger.info("Updating PR #{branch.pr_number} with mergability comment.")

    branch.repo.with_github_service do |github|
      github.create_issue_comments(branch.pr_number, "#{tag}This pull request is not mergeable.  Please rebase and repush.")
    end
  end

  def apply_label
    logger.info("Updating PR #{branch.pr_number} with label #{LABEL.inspect}.")

    branch.repo.with_github_service do |github|
      github.add_issue_labels(branch.pr_number, LABEL)
    end
  end

  def remove_label
    logger.info("Updating PR #{branch.pr_number} my removing label #{LABEL.inspect}.")

    branch.repo.with_github_service do |github|
      begin
        github.issues.labels.remove(github.user, github.repo, branch.pr_number, :label_name => LABEL)
      rescue Github::Error::NotFound # This label is not currently applied, skip
      end
    end
  end
end
