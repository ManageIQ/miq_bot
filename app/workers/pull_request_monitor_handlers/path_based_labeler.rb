class PullRequestMonitorHandlers::PathBasedLabeler
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
    label_rules.each do |rule|
      if diff_file_names.any? { |file_name| file_name =~ Regexp.new(rule.pattern) }
        GithubService.add_labels_to_an_issue(fq_repo_name, pr_number, [rule.label])
      end
    end
  end

  def label_rules
    Settings.path_based_labeler.rules
  end
end
