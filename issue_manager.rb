require 'octokit'
require 'yaml'
require 'FileUtils'
require_relative 'githubapi/git_hub_api'
require_relative 'logging'

ISSUE_MANAGER_YAML_FILE       = File.join(File.dirname(__FILE__), '/issue_manager.yml')
GITHUB_CREDENTIALS_YAML_FILE  = File.join(File.dirname(__FILE__), '/issue_manager_credentials.yml')
ORGANIZATION = "ManageIQ"


COMMANDS = {
  "add_label"     => :add_labels,
  "add_labels"    => :add_labels,
  "rm_label"      => :remove_labels,
  "rm_labels"     => :remove_labels,
  "remove_label"  => :remove_labels,
  "remove_labels" => :remove_labels,
  "assign"        => :assign,
  "set_milestone" => :set_milestone
}  

class IssueManager

  include Logging
  include GitHubApi

  def initialize(repo_name)
    get_credentials
    @user         = GitHubApi.connect(@username, @password)
    @org          = @user.find_organization(ORGANIZATION)
    @repo         = @org.get_repository(repo_name)
    @timestamps   = load_yaml_file
    @timestamps ||= Hash.new(0)
  end

  def get_notifications
    notifications = @repo.notifications
    notifications.each do |notification|
      process_notification(notification)
    end
  end 

  def process_notification(notification)
    issue               = notification.issue
    process_issue(issue)
    notification.mark_thread_as_read
  end

  def process_issue(issue)
    issue.comments.each do |comment|
      process(comment)
    end
  end

  # comment: The goal is to find the comments that have not been processed by the BOT. 
  # As each comment is processed it overwrites the entry in the hash @timestamps for this
  # issue ID. Then the hash @timestamps is written to a yaml file.
  # When a new comment is made it will be processed if its timestamp is more recent
  # than the one in the hash/yaml for this issue 

  def process(comment)

    last_comment_timestamp = @timestamps[comment.issue.number] || 0
    return if last_comment_timestamp != 0 && last_comment_timestamp >= comment.updated_at

    # bot command or not, we need to update the yaml file so next time we 
    # pull in the comments we can skip this one.

    add_and_yaml_timestamps(comment.updated_at, comment.issue.number)   

    lines = comment.body.split("\n")    
    lines.each do |line|
      process_command(line, comment.author, comment.issue)
    end
  end
 
  def process_command(line, author, issue)
    match = line.match(/^@cfme-bot\s+([-@a-z0-9_]+)\s+/i)
    return if !match

    command       = match.captures.first
    command_value = match.post_match
    method_name   = COMMANDS[command].to_s

    if method_name.empty?
      message = "@#{author} unrecognized command '#{command}', ignoring..."
      issue.add_comment(message)
      return
    else
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

  def get_credentials
    begin
      credentials = YAML.load_file(GITHUB_CREDENTIALS_YAML_FILE)
    rescue Errno::ENOENT
      logger.error("Missing file #{GITHUB_CREDENTIALS_YAML_FILE}. Exiting...")
      exit 1
    end 

    @username      = credentials["username"] 
    @password      = credentials["password"]

    if @username.nil? || @password.nil?
      logger.error("Credentials are not configured. Exiting..") 
      exit 1
    end
  end

  def load_yaml_file
    begin
      @timestamps = YAML.load_file(ISSUE_MANAGER_YAML_FILE)
    rescue Errno::ENOENT
      logger.warn("#{Time.now} #{ISSUE_MANAGER_YAML_FILE} was missing, recreating it...")
      FileUtils.touch(ISSUE_MANAGER_YAML_FILE)
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

