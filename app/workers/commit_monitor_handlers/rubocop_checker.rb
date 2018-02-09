class CommitMonitorHandlers::RubocopChecker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot_glacial

  include BranchWorkerMixin
  include CodeAnalysisMixin

  def self.handled_branch_modes
    [:pr]
  end

  attr_reader :results

  def perform(branch_id, _new_commits)
    return unless find_branch(branch_id, :pr)

    process_branch
  end

  private

  def process_branch
    @results = merged_linter_results
    unless @results["files"].blank?
      diff_details = diff_details_for_merge
      @results     = RubocopResultsFilter.new(results, diff_details).filtered
    end

    replace_rubocop_comments
  rescue GitService::UnmergeableError
    nil # Avoid working on unmergeable PRs
  end

  def rubocop_comments
    MessageBuilder.new(results, branch).comments
  end

  def replace_rubocop_comments
    logger.info("Updating PR #{pr_number} with rubocop comment.")
    GithubService.replace_comments(fq_repo_name, pr_number, rubocop_comments) do |old_comment|
      rubocop_comment?(old_comment)
    end
  end

  def rubocop_comment?(comment)
    comment.body.start_with?("<rubocop />")
  end
end
