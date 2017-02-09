class PullRequestMonitorHandlers::MergeTargetTitler
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  include BranchWorkerMixin

  def perform(branch_id)
    return unless find_branch(branch_id, :pr)
    return unless verify_branch_enabled

    process_branch
  end

  private

  def process_branch
    apply_title if merge_target != "master" && !already_titled?
  end

  def already_titled?
    pr_title_tags.map(&:downcase).include?(merge_target.downcase)
  end

  def apply_title
    logger.info("Updating PR #{pr_number} with title change for merge target #{merge_target}.")
    GithubService.update_pull_request(branch.repo.name, pr_number, :title => new_pr_title)
  end

  def new_pr_title
    "[#{merge_target.upcase}] #{pr_title}"
  end
end
