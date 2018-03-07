require 'rugged'

class CommitMonitorHandlers::CommitRange::RubocopChecker
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

    type = if results["files"].none? { |f| f["offenses"].any? } # zero offenses - green status
             :zero
           elsif results["files"].any? { |f| f["offenses"].any? { |o| o["severity"] == "error" || o["severity"] == "fatal" } } # catastrophic offense(s) - red status
             :bomb
           else # informative offenses excluding catastrophic offense(s) - green status
             :warn
           end

    GithubService.replace_comments(fq_repo_name, pr_number, rubocop_comments, type, commits.last) { |old_comment| rubocop_comment?(old_comment) }
  end

  def rubocop_comment?(comment)
    comment.body.start_with?("<rubocop />")
  end
end
