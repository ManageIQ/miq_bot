class CommitMonitorHandlers::CommitRange::MergeabilityChecker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  include BranchWorkerMixin

  def self.handled_branch_modes
    [:pr, :regular]
  end

  def perform(branch_id, _new_commits)
    return unless find_branch(branch_id)

    case branch.mode
    when :pr
      # When a PR branch updates, run the mergeability check inline
      PrMergeabilityChecker.perform_sync(branch.id)
    when :regular
      # When a regular branch updates, find all PRs that target it and queue up mergeability checks
      repo.pr_branches.where(:merge_target => branch.name).each do |pr|
        logger.info("Queueing PrMergeabilityChecker for PR #{pr.fq_pr_number}.")
        PrMergeabilityChecker.perform_async(pr.id)
      end
    end
  end
end
