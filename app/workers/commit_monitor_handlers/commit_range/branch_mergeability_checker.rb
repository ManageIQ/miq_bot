class CommitMonitorHandlers::CommitRange::BranchMergeabilityChecker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  include BranchWorkerMixin

  def self.handled_branch_modes
    [:regular]
  end

  def perform(branch_id, _new_commits)
    return unless find_branch(branch_id, :regular)

    repo.pr_branches.where(:merge_target => branch.name).each do |pr|
      logger.info("Queueing PrMergeabilityChecker for PR #{pr.fq_pr_number}.")
      PrMergeabilityChecker.perform_async(pr.id)
    end
  end
end
