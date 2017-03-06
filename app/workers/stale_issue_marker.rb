class StaleIssueMarker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot_glacial, :retry => false

  include SidekiqWorkerMixin

  # If an issue/pr has any of these labels, it will not be marked as stale or closed
  PINNED_LABELS    = ['pinned'].freeze

  STALE_LABEL_NAME = 'stale'.freeze
  STALE_ISSUE_MESSAGE = <<-EOS.freeze
This issue has been automatically marked as stale because it has not been updated for at least 6 months.

If you can still reproduce this issue on the current release or on `master`, please reply with all of the information you have about it in order to keep the issue open.

Thank you for all your contributions!
  EOS
  CLOSABLE_PR_MESSAGE = <<-EOS.freeze
This pull request has been automatically closed because it has not been updated for at least 6 months.

Feel free to reopen this pull request if these changes are still valid.

Thank you for all your contributions!
  EOS

  attr_reader :fq_repo_name

  def perform(fq_repo_name)
    @fq_repo_name = fq_repo_name
    raise "The label #{STALE_LABEL_NAME} does not exist on #{fq_repo_name}" unless GithubService.valid_label?(fq_repo_name, STALE_LABEL_NAME)

    GithubService.issues(fq_repo_name, :state => :open, :sort => :updated, :direction => :asc).each do |issue|
      pinned = (issue.labels & PINNED_LABELS).present?

      if issue.updated_at < stale_date && !pinned
        if issue.pull_request?
          closable_prs << issue
        else
          stale_issues << issue
        end
      end
    end

    stale_issues.each do |issue|
      next if issue.labels.include?(STALE_LABEL_NAME)
      logger.info("[#{Time.now.utc}] - Marking issue #{fq_repo_name}##{issue.number} as stale")
      issue.add_labels([STALE_LABEL_NAME])
      issue.add_comment(STALE_ISSUE_MESSAGE)
    end

    closable_prs.each do |pr|
      logger.info("[#{Time.now.utc}] - Closing stale PR #{fq_repo_name}##{pr.number}")
      GithubService.close_pull_request(pr.fq_repo_name, pr.number)
      pr.add_comment(CLOSABLE_PR_MESSAGE)
    end
  end

  private

  def stale_date
    @stale_date ||= 6.months.ago
  end

  def stale_issues
    @stale_issues ||= []
  end

  def closable_prs
    @closable_prs ||= []
  end
end
