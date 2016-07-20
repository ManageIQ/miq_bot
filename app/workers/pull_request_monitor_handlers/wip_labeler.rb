class PullRequestMonitorHandlers::WipLabeler
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  include BranchWorkerMixin

  LABEL = "wip".freeze

  def perform(branch_id)
    return unless find_branch(branch_id, :pr)
    return unless verify_branch_enabled

    process_branch
  end

  private

  def process_branch
    apply_label if wip_in_title?
  end

  def wip_in_title?
    pr_title_tags.map(&:downcase).include?(LABEL)
  end

  def apply_label
    branch.repo.with_github_service do |github|
      logger.info("Updating PR #{pr_number} with label #{LABEL.inspect}.")
      github.add_issue_labels(pr_number, LABEL)
    end
  end
end
