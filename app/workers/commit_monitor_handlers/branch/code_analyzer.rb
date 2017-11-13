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
    @results = merged_linter_results
    offense_count = @results.fetch_path("summary", "offense_count")
    branch.update_attributes(:linter_offense_count => offense_count)
  end
end
