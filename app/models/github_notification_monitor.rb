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

  def self.build(organization_name, repo_name)
    username     = Settings.github_credentials.username
    password     = Settings.github_credentials.password
    raise "no GitHub credentials defined" if username.nil? || password.nil?

    fq_repo_name = "#{organization_name}/#{repo_name}"
    user         = GitHubApi.connect(username, password)
    org          = user.find_organization(organization_name)
    repo         = org.get_repository(repo_name)
    new(repo, username, org, fq_repo_name)
  end

  def initialize(repo, username, org, fq_repo_name)
    @repo = repo
    @username = username
    @org = org
    @fq_repo_name = fq_repo_name
  end

  def logger
    Rails.logger
  end

  def process_notifications
    notifications = @repo.notifications
    notifications.each do |notification|
      process_notification(notification)
    end
  end

  # A notification only notifies about a change to an issue thread, but
  # not which specific comments were added.  Thus, we keep track of the
  # last_processed_timestamp, and check every comment in the issue thread
  # skipping them until we are at the last processed comment.
  def process_notification(notification)
    process_issue_thread(notification.issue)
    notification.mark_thread_as_read
  end

  def process_issue_thread(issue)
    process_issue_title(issue)
    process_issue_comment(issue, issue.author, issue.created_at, issue.body)
    issue.comments.each do |comment|
      process_issue_comment(comment.issue, comment.author, comment.updated_at, comment.body)
    end
  end

  def process_issue_title(issue)
    if issue.title_indicates_wip?
      issue.add_labels([GitHubApi::Label.new(nil, "wip", nil)]) unless issue.applied_label?("wip")
    else
      issue.remove_label("wip") if issue.applied_label?("wip")
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
    # First reload the label cache if it's an invalid milestone
    @repo.refresh_milestones unless @repo.valid_milestone?(milestone)

    # Then see if it's *still* invalid
    @repo.valid_milestone?(milestone)
  end

  def assign(user, author, issue)
    user       = user.strip
    clean_user = user.delete('@')

    if valid_member?(clean_user)
      issue.assign(clean_user)
    else
      issue.add_comment("@#{author} #{user} is an invalid user, ignoring...")
    end
  end

  def valid_member?(user)
    # First reload the member cache if it's an invalid member
    @org.refresh_members unless @org.member?(user)

    # Then see if it's *still* invalid
    @org.member?(user)
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
      valid.collect! { |l| GitHubApi::Label.new(@repo, l, issue) }
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
    label_names = command_value.split(",").collect(&:strip)
    validate_labels(label_names)
  end

  def validate_labels(label_names)
    # First reload the label cache if there are any invalid labels
    @repo.refresh_labels unless label_names.all? { |l| @repo.valid_label?(l) }

    # Then see if any are *still* invalid and split the list
    label_names.partition { |l| @repo.valid_label?(l) }
  end

  def timestamps
    timestamps_full_hash["timestamps"][@fq_repo_name]
  end

  def update_timestamp(updated_at, issue_number)
    timestamps[issue_number] = updated_at
    save_timestamps
  end

  private

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
end
