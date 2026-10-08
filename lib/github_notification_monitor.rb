class GithubNotificationMonitor
  COMMANDS = Hash.new do |h, k|
    normalized = k.to_s.tr("-", "_")              # Support - or _ in command
    normalized.chop! if normalized.end_with?("s") # Support singular or plural
    h[normalized]    if h.key?(normalized)
  end.merge(
    "add_label"       => :add_labels,
    "remove_label"    => :remove_labels,
    "rm_label"        => :remove_labels,
    "assign"          => :assign,
    "unassign"        => :unassign,
    "add_reviewer"    => :add_reviewer,
    "remove_reviewer" => :remove_reviewer,
    "set_milestone"   => :set_milestone
  ).freeze

  def initialize(fq_repo_name, notifications)
    @username = Settings.github_credentials.username
    @repo = Repo.find_by!(:name => fq_repo_name)
    @fq_repo_name = fq_repo_name
    @notifications = notifications
  end

  def process_notifications
    @notifications.each do |notification|
      process_notification(notification)
    end
  end

  private

  # A notification only notifies about a change to an issue thread, but
  # not which specific comments were added.  Thus, we keep track of the
  # last_processed_at timestamp, and check every comment in the issue thread
  # skipping them until we are at the last processed comment.
  def process_notification(notification)
    if notification.issue_number.present?
      issue = GithubService.issue(@fq_repo_name, notification.issue_number)
      process_issue_thread(issue)
    else
      logger.warn("Skipping processing of notification due to missing issue number: #{notification}")
    end
    notification.mark_thread_as_read
  end

  def process_issue_thread(issue)
    @dispatcher = GithubService::CommandDispatcher.new(issue)

    process_issue_comment(issue, issue.author, issue.created_at, issue.body)
    GithubService.issue_comments(@fq_repo_name, issue.number).each do |comment|
      process_issue_comment(issue, comment.author, comment.updated_at, comment.body)
    end
  end

  def process_issue_comment(issue, author, timestamp, body)
    if body.blank?
      logger.warn("Skipping comment due to empty body. Issue: #{issue.url} Author: #{author}, Timestamp: #{timestamp}")
      return
    end

    issue_record = @repo.issues.find_or_initialize_by(:number => issue.number)
    return if issue_record.last_processed_at && timestamp <= issue_record.last_processed_at

    @dispatcher.dispatch!(:issuer => author, :text => body)
    issue_record.update!(:last_processed_at => timestamp)
  end

  def logger
    Rails.logger
  end
end
