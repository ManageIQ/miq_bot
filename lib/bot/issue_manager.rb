require 'octokit'
require 'yaml'
require 'fileutils'
require_relative 'rails_config_settings'
require_relative 'githubapi/git_hub_api'
require_relative 'huboard'
require_relative 'logging'

class IssueManager
  include Logging
  include GitHubApi

  ISSUE_MANAGER_YAML_FILE = File.join(File.dirname(__FILE__), 'config/issue_manager.yml')
  LABELS_YAML_FILE = File.join(File.dirname(__FILE__), 'config/labels.yml')
  ORGANIZATION = "ManageIQ"

  COMMANDS = Hash.new do |h, k|
    normalized = k.to_s.gsub("-", "_")            # Support - or _ in command
    normalized.chop! if normalized.end_with?("s") # Support singular or plural
    h[normalized]    if h.key?(normalized)
  end.merge(
    "add_label"     => :add_labels,
    "remove_label"  => :remove_labels,
    "rm_label"      => :remove_labels,
    "assign"        => :assign,
    "set_milestone" => :set_milestone,
    "state"         => :state
  ).freeze

  def initialize(repo_name)
    get_credentials
    @user         = GitHubApi.connect(@username, @password)
    @org          = @user.find_organization(ORGANIZATION)
    @repo         = @org.get_repository(repo_name)
    @timestamps   = load_yaml_file(ISSUE_MANAGER_YAML_FILE)
    @timestamps ||= Hash.new(0)
    @notify       = load_yaml_file(LABELS_YAML_FILE)
    @labels     ||= Hash.new(0)
  end

  def get_notifications
    notifications = @repo.notifications
    notifications.each do |notification|
      process_notification(notification)
    end
  end

  def process_notification(notification)
    issue = notification.issue
    process(issue)
    notification.mark_thread_as_read
  end

  def process(issue)
    process_input(issue, issue.author, issue.created_at, issue.body)
    issue.comments.each do |comment|
      process_input(comment.issue, comment.author, comment.updated_at, comment.body)
    end
  end

  # comment: The goal is to find the comments that have not been processed by the BOT.
  # As each comment is processed it overwrites the entry in the hash @timestamps for this
  # issue ID. Then the hash @timestamps is written to a yaml file.
  # When a new comment is made it will be processed if its timestamp is more recent
  # than the one in the hash/yaml for this issue

  def process_input(issue, author, timestamp, body)
    last_comment_timestamp = @timestamps[issue.number] || 0
    return if last_comment_timestamp != 0 && last_comment_timestamp >= timestamp

    # bot command or not, we need to update the yaml file so next time we
    # pull in the comments we can skip this one.

    add_and_yaml_timestamps(timestamp, issue.number)
    process_message(body, author, issue)
  end

  def process_message(body, author, issue)
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

    if @repo.valid_milestone?(milestone)
      issue.set_milestone(milestone)
    else
      message = "@#{author} Milestone #{milestone} is not recognized, ignoring..."
      issue.add_comment(message)
    end
  end

  def assign(assign_to_user_arg, author, issue)
    assign_to_user = assign_to_user_arg.delete('@').rstrip
    if @org.member?(assign_to_user)
      issue.assign(assign_to_user)
    else
      issue.add_comment("@#{author} #{assign_to_user_arg} is an invalid user, ignoring... ")
    end
  end

  def add_labels(command_value, author, issue)
    new_label_names   = split(command_value)
    valid_labels      = []
    invalid_labels    = []

    new_label_names.each do |new_label|
      new_label       = new_label.strip
      if @repo.valid_label?(new_label)
        label         = GitHubApi::Label.new(@repo, new_label, issue)
        valid_labels << label
        send_notification(label)
      else
        invalid_labels << new_label
      end
    end

    if !invalid_labels.empty?
      message = "@#{author} Cannot apply the following label(s) because they are not recognized: "
      message << invalid_labels.join(", ")
      issue.add_comment(message)
    end
    if !valid_labels.empty?
      issue.add_labels(valid_labels)
    end
  end

  def remove_labels(command_value, author, issue)
    invalid_labels = []
    labels_array   = split(command_value)

    labels_array.each do |label_text|
      label_text.strip!
      if issue.applied_label?(label_text)
        issue.remove_label(label_text)
      else
        invalid_labels << label_text
      end
    end
    unless invalid_labels.empty?
      message = "@#{author} Cannot remove the following label(s) because they have not been applied: "
      message << invalid_labels.join(", ")
      issue.add_comment(message)
    end
  end

  def split(labels)
    labels.split(",")
  end

  def state(state, author, issue)
    state                     = state.strip
    huboard_labels            = get_huboard_labels
    existing_huboard_lbl      = (huboard_labels & issue.applied_labels.keys).last
    existing_huboard_lbl_idx  = huboard_labels.index(existing_huboard_lbl)
    index = get_new_huboard_label_idx(existing_huboard_lbl_idx, state, issue, author)

    return unless valid_state?(index, author, issue)

    if existing_huboard_lbl
      issue.remove_label(existing_huboard_lbl)
    end
    add_new_huboard_label(index, author, issue)
  end

  def get_new_huboard_label_idx(index, state, issue, author)

    if state.downcase == "prev"
      index -= 1
    elsif state.downcase == "next"
      index += 1
    elsif state.match(/\d+/)
      index = state.to_i
    else
      issue.add_comment("@#{author} - the command value '#{state}' is not recognized. Ignoring...")
    end

    return index
  end

  def valid_state?(state_id, author, issue)
    if !Huboard.valid_state?(state_id)
      issue.add_comment("@#{author} state #{state_id} is invalid. Ignoring...")
      return false
    else
      return true
    end
  end

  def add_new_huboard_label(state_id, author, issue)
    text = get_huboard_label_text(state_id)
    add_labels(text, author, issue)
  end

  def get_huboard_label_text(state_id)
    Huboard.get_label_text(state_id)
  end

  def get_existing_huboard_label_idx(huboard_label)
    Huboard.get_labels.index(huboard_label)
  end

  def get_huboard_labels
    Huboard.get_labels(@repo)
  end

  def get_credentials
    @username = Settings.github_credentials.username
    @password = Settings.github_credentials.password

    if @username.nil? || @password.nil?
      logger.error("Credentials are not configured. Exiting..")
      exit 1
    end
  end

  def send_notification(label)
    begin
      if @notify.has_key?(label)
        if @notify[label].has_key?('mailto')
          @notify[label]['mailto'].each do |address|
            UserNotifier.send_notification_email(address, issue.number, label).deliver
          end
        end
      end
    rescue Exception => msg
      logger.error("Couldn't send email notification. Exception: #{msg}")
    end
  end

  def load_yaml_file(file)
    begin
      YAML.load_file(file)
    rescue Errno::ENOENT
      logger.warn("#{Time.now} #{file} was missing, recreating it...")
      FileUtils.touch(file)
      retry
    end
  end

  def add_and_yaml_timestamps(updated_at, issue_number)
    @timestamps[issue_number]=updated_at
    File.open(ISSUE_MANAGER_YAML_FILE, 'w+') do |f|
      YAML.dump(@timestamps, f)
    end
  end
end
