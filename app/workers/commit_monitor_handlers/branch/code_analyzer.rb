require 'rugged'

class CommitMonitorHandlers::Branch::CodeAnalyzer
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot_glacial

  include BranchWorkerMixin
  include ::CodeAnalysisMixin

  def self.handled_branch_modes
    [:regular]
  end

  def perform(branch_id)
    return unless find_branch(branch_id, :regular)

    analyze
  end

  private

  def analyze
    branch.repo.git_fetch
    run_linters
    offense_count = @results.fetch_path("summary", "offense_count")
    branch.update_attributes(:linter_offense_count => offense_count)
  end

  def run_linters
    unmerged_results = run_all_linters
    if unmerged_results.empty?
      @results = {"files" => []}
    else
      @results = merge_linter_results(*unmerged_results)
    end
  end
end
