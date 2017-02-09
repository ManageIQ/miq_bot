require 'rugged'

class CommitMonitorHandlers::CommitRange::GemChangesLabeler
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  include BranchWorkerMixin

  LABEL = "gem changes".freeze

  def self.handled_branch_modes
    [:pr]
  end

  def perform(branch_id, _new_commits)
    return unless find_branch(branch_id, :pr)
    return unless verify_branch_enabled

    process_branch
  end

  private

  def process_branch
    apply_label if gem_changes_in_diff?
  end

  def gem_changes_in_diff?
    branch.git_service.diff.new_files.any? { |file| gem_changes?(file) }
  rescue Rugged::IndexError
    # Failed to create merge index, no point in trying
    return false
  end

  def gem_changes?(file)
    File.basename(file) == "Gemfile" || file.to_s.end_with?(".gemspec")
  end

  def apply_label
    logger.info("Updating PR #{pr_number} with label #{LABEL.inspect}.")
    NewGithubService.add_labels_to_an_issue(fq_repo_name, pr_number, [LABEL])
  end
end
