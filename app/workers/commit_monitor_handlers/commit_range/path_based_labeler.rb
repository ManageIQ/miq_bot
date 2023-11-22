class CommitMonitorHandlers::CommitRange::PathBasedLabeler
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  include BranchWorkerMixin

  def self.handled_branch_modes
    [:pr]
  end

  def perform(branch_id, _new_commits)
    return unless find_branch(branch_id, :pr)

    process_branch
  end

  private

  def process_branch
    labels = []
    label_rules.each do |rule|
      if diff_file_names.any? { |file_name| file_name =~ rule.regex }
        labels << rule.label
      end
    end
    GithubService.add_labels_to_an_issue(fq_repo_name, pr_number, labels) if labels.present?
  rescue GitService::UnmergeableError
    # Ignore unmergeable PRs
  end

  def label_rules
    Settings.path_based_labeler.rules[fq_repo_name] || []
  end
end
