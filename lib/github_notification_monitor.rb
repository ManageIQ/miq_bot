class GithubNotificationMonitor
  GITHUB_NOTIFICATION_MONITOR_YAML_FILE = Rails.root.join("config", "github_notification_monitor.yml")

  COMMANDS = Hash.new do |h, k|
    normalized = k.to_s.gsub("-", "_")            # Support - or _ in command
    normalized.chop! if normalized.end_with?("s") # Support singular or plural
    h[normalized]    if h.key?(normalized)
  end.merge(
    "add_label"     => :add_labels,
    "remove_label"  => :remove_labels,
    "rm_label"      => :remove_labels,
    "assign"        => :assign,
    "set_milestone" => :set_milestone
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
    issue = GithubService.issue(@fq_repo_name, notification.issue_number)
    process_issue_thread(issue)
    notification.mark_thread_as_read
  end

  def process_issue_thread(issue)
    process_issue_comment(issue, issue.author, issue.created_at, issue.body)
    GithubService.issue_comments(@fq_repo_name, issue.number).each do |comment|
      process_issue_comment(issue, comment.author, comment.updated_at, comment.body)
    end
  end

  def process_issue_comment(issue, author, timestamp, body)
    last_processed_timestamp = timestamps[issue.number] || Time.at(0)
    return if timestamp <= last_processed_timestamp

    update_timestamp(timestamp, issue.number)
    process_issue_comment_body(body, author, issue)
  end

  def process_issue_comment_body(body, author, issue)
    lines = body.split("\n")
    lines.each do |line|
      process_command(line, author, issue)
    end
  end

  def process_command(line, author, issue)
    match = line.strip.match(/^@#{@username}\s+([-@a-z0-9_]+)\s+/i)

    return if !match

    command       = match.captures.first
    command_value = match.post_match
    method_name   = COMMANDS[command].to_s

    if method_name.empty?
      message = <<-EOMSG
@#{author} unrecognized command '#{command}', ignoring...

Accepted commands are: #{COMMANDS.keys.join(", ")}
EOMSG
      issue.add_comment(message)
      return
    else
      logger.info("Running command #{method_name}(#{command_value.inspect}, #{author.inspect}, #{issue.number})")
      self.send(method_name, command_value, author, issue)
    end
  end

  def set_milestone(milestone, author, issue)
    milestone = milestone.strip

    if valid_milestone?(milestone)
      issue.set_milestone(milestone)
    else
      message = "@#{author} Milestone #{milestone} is not recognized, ignoring..."
      issue.add_comment(message)
    end
  end

  def valid_milestone?(milestone)
    # First reload the cache if it's an invalid milestone
    GithubService.refresh_milestones(@fq_repo_name) unless GithubService.valid_milestone?(@fq_repo_name, milestone)

    # Then see if it's *still* invalid
    GithubService.valid_milestone?(@fq_repo_name, milestone)
  end

  def assign(user, author, issue)
    user       = user.strip
    clean_user = user.delete('@')

    if valid_assignee?(clean_user)
      issue.assign(clean_user)
    else
      issue.add_comment("@#{author} #{user} is an invalid assignee, ignoring...")
    end
  end

  def valid_assignee?(user)
    # First reload the cache if it's an invalid assignee
    GithubService.refresh_assignees(@fq_repo_name) unless GithubService.valid_assignee?(@fq_repo_name, user)

    # Then see if it's *still* invalid
    GithubService.valid_assignee?(@fq_repo_name, user)
  end

  def add_labels(command_value, author, issue)
    valid, invalid = extract_label_names(command_value)

    if invalid.any?
      message = "@#{author} Cannot apply the following label#{"s" if invalid.length > 1} because they are not recognized: "
      message << invalid.join(", ")
      issue.add_comment(message)
    end

    if valid.any?
      valid.reject!  { |l| issue.applied_label?(l) }
      issue.add_labels(valid)
    end
  end

  def remove_labels(command_value, author, issue)
    valid, invalid = extract_label_names(command_value)

    if invalid.any?
      message = "@#{author} Cannot remove the following label#{"s" if invalid.length > 1} because they are not recognized: "
      message << invalid.join(", ")
      issue.add_comment(message)
    end

    valid.each do |l|
      issue.remove_label(l) if issue.applied_label?(l)
    end
  end

  def extract_label_names(command_value)
    label_names = command_value.split(",").map { |label| label.strip.downcase }
    validate_labels(label_names)
  end

  def validate_labels(label_names)
    # First reload the cache if there are any invalid labels
    GithubService.refresh_labels(@fq_repo_name) unless label_names.all? { |l| GithubService.valid_label?(@fq_repo_name, l) }

    # Then see if any are *still* invalid and split the list
    label_names.partition { |l| GithubService.valid_label?(@fq_repo_name, l) }
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
