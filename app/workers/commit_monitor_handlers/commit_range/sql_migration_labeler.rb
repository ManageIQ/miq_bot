require 'rugged'

class CommitMonitorHandlers::CommitRange::SqlMigrationLabeler
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  include BranchWorkerMixin

  LABEL = "sql migration".freeze

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
    apply_label if migrations_in_diff?
  end

  def migrations_in_diff?
    branch.git_service.diff.new_files.any? { |file| migration?(file) }
  rescue Rugged::IndexError
    # Failed to create merge index, no point in trying
    return false
  end

  def migration?(file)
    file.include?("db/migrate/") && file.end_with?(".rb") && !file.include?("spec/db/migrate/")
  end

  def apply_label
    branch.repo.with_github_service do |github|
      logger.info("Updating PR #{pr_number} with label #{LABEL.inspect}.")
      github.add_issue_labels(pr_number, LABEL)
    end
  end
end
