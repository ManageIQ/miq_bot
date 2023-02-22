class GithubNotificationMonitor
  GITHUB_NOTIFICATION_MONITOR_YAML_FILE = Rails.root.join("config", "github_notification_monitor.yml")

  COMMANDS = Hash.new do |h, k|
    normalized = k.to_s.gsub("-", "_")            # Support - or _ in command
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

  def initialize(fq_repo_name)
    @username = Settings.github_credentials.username
    @fq_repo_name = fq_repo_name
  end

  def process_notifications
    GithubService.repository_notifications(@fq_repo_name, "all" => false).each do |notification|
      process_notification(notification)
    end
  end

  private

  # A notification only notifies about a change to an issue thread, but
  # not which specific comments were added.  Thus, we keep track of the
  # last_processed_timestamp, and check every comment in the issue thread
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

    last_processed_timestamp = timestamps[issue.number] || Time.at(0)
    return if timestamp <= last_processed_timestamp

    @dispatcher.dispatch!(:issuer => author, :text => body)
    update_timestamp(timestamp, issue.number)
  end

  def timestamps
    timestamps_full_hash["timestamps"][@fq_repo_name]
  end

  def update_timestamp(updated_at, issue_number)
    timestamps[issue_number] = updated_at
    save_timestamps
  end

  def timestamps_full_hash
    @timestamps_full_hash ||=
      (YAML.load_file(GITHUB_NOTIFICATION_MONITOR_YAML_FILE) || {}).tap do |h|
        h["timestamps"] ||= {}
        h["timestamps"][@fq_repo_name] ||= {}
      end
  rescue Errno::ENOENT
    logger.warn("#{Time.now} #{GITHUB_NOTIFICATION_MONITOR_YAML_FILE} was missing, recreating it...")
    FileUtils.touch(GITHUB_NOTIFICATION_MONITOR_YAML_FILE)
    retry
  end

  def save_timestamps
    File.write(GITHUB_NOTIFICATION_MONITOR_YAML_FILE, timestamps_full_hash.to_yaml)
  end

  def logger
    Rails.logger
  end
end
