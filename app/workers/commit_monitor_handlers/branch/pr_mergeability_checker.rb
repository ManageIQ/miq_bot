class CommitMonitorHandlers::Branch::PrMergeabilityChecker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot_glacial

  include BranchWorkerMixin

  def self.handled_branch_modes
    [:pr]
  end

  def perform(branch_id)
    return unless find_branch(branch_id, :pr)

    process_mergeability
  end

  private

  def tag
    "<pr_mergeability_checker />"
  end

  def process_mergeability
    was_mergeable       = branch.mergeable?
    currently_mergeable = branch.git_service.mergeable?

    write_to_github if was_mergeable && !currently_mergeable

    # Update columns directly to avoid collisions wrt the serialized column issue
    branch.update_columns(:mergeable => currently_mergeable)
  end

  def write_to_github
    logger.info("Updating PR #{branch.pr_number} with mergability comment.")

    branch.repo.with_github_service do |github|
      github.create_issue_comments(branch.pr_number, "#{tag}This pull request is not mergeable.  Please rebase and repush.")
    end
  end
end
