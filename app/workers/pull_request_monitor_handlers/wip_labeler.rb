class PullRequestMonitorHandlers::WipLabeler
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  include BranchWorkerMixin

  LABEL = "wip".freeze

  def perform(branch_id)
    return unless find_branch(branch_id, :pr)

    process_branch
  end

  private

  def process_branch
    if wip_in_title?
      apply_label
    else
      remove_label
    end
  end

  def wip_in_title?
    pr_title_tags.map(&:downcase).include?(LABEL)
  end

  def apply_label
    logger.info("Updating PR #{pr_number} with label #{LABEL.inspect}.")
    GithubService.add_labels_to_an_issue(fq_repo_name, pr_number, [LABEL])
  end

  def remove_label
    logger.info("Updating PR #{pr_number} without label #{LABEL.inspect}.")
    GithubService.remove_label(fq_repo_name, pr_number, LABEL)
  end
end
