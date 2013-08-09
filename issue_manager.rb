#!/usr/bin/env ruby
require 'bundler/setup'
require 'octokit'
require 'yaml'
require 'time'
require 'logger'
require 'fileutils'

ISSUE_MANAGER_YAML_FILE       = File.join(File.dirname(__FILE__), '/issue_manager.yml')
ISSUE_MANAGER_LOG_FILE        = File.join(File.dirname(__FILE__), '/issue_manager.log')
GITHUB_CREDENTIALS_YAML_FILE  = File.join(File.dirname(__FILE__), '/issue_manager_credentials.yml')

ORGANIZATION  = "ManageIQ"

class IssueManager

  COMMANDS = {
    "add_label"     => :add_labels_to_an_issue,
    "add_labels"    => :add_labels_to_an_issue,
    "rm_label"      => :remove_labels_from_issue,
    "rm_labels"     => :remove_labels_from_issue,
    "remove_label"  => :remove_labels_from_issue,
    "remove_labels" => :remove_labels_from_issue,
    "assign"        => :assign_to_issue,
    "set_milestone" => :set_milestone
  }

  def self.logger
    @logger ||= Logger.new(ISSUE_MANAGER_LOG_FILE)
  end

  def self.logger=(l)
    @logger = l
  end

  def logger
    self.class.logger
  end

  def initialize(repo)
    @repo = "#{ORGANIZATION}/#{repo}"
    @timestamps = load_yaml_file
    @timestamps ||= Hash.new(0)

    get_credentials
    load_permitted_labels
    load_organization_members
    load_milestones
  end

  def get_notifications
    notifications = client.repository_notifications(@repo, "all" => false)
    notifications.each do |notification|
      process_notification(notification)
    end
  end
  
  private

  attr_accessor :permitted_labels

  def client
    @client ||= Octokit::Client.new(:login => @username, :password => @password, :auto_traversal => true)
  end

  def get_credentials
    @credentials = load_credentials_yaml_file
    @username = @credentials["username"] 
    @password = @credentials["password"]

    if @username.nil? || @password.nil?
      logger.error("Credentials are not configured. Exiting..") 
      exit 1
    end
  end

  def load_permitted_labels
    @permitted_labels ||= Set.new
    labels = client.labels(@repo)
    labels.each do |label|
      @permitted_labels.add(label.name)
    end
  end

  def load_milestones
    @milestones = {}
    defined_milestones = client.list_milestones(@repo)
    defined_milestones.each do |milestone|
      @milestones[milestone.title] = milestone.number
    end
  end

  def print_issue(issue)
    logger.info("Title:\t #{issue.title}")
    logger.info("Body:\t #{issue.body}")
    logger.info("Number:\t #{issue.number}")
    logger.info("State:\t #{issue.state}")
  end

  def print_notification(notification)
    logger.info("Notification repo: #{notification.repository.name}")
    logger.info("Notification subject title: #{notification.subject.title}")
  end

  def print_comment(comment)
    logger.info("\tComment body: #{comment.body}")
    logger.info("\tComment added at: #{comment.updated_at}\n")
  end

  def extract_comment_id(notification)
    notification.subject.latest_comment_url.match(/[0-9]+\Z/).to_s
  end

  def extract_issue_id(notification)
    notification.subject.url.match(/[0-9]+\Z/).to_s
  end

  def extract_thread_id(notification)
    notification.url.match(/[0-9]+\Z/).to_s
  end

  def make_repo_name(notification)
    "ManageIQ/#{notification.repository.name}"
  end

  def process_notification(notification)
    notification_repo   = make_repo_name(notification)
    thread_id           = extract_thread_id(notification)
    issue_id            = extract_issue_id(notification)
    issue               = client.issue(notification_repo, issue_id)   
    comments            = client.issue_comments(notification_repo, issue_id)
    comments.each do |comment|
      process_comment(comment, issue, notification_repo) 
    end
    mark_thread_as_read(thread_id)
  end

    # comment: The goal is to find the comments that have not been processed by the BOT. 
    # As each comment is processed it overwrites the entry in the hash @timestamps for this
    # issue ID. Then the hash @timestamps is written to a yaml file.
    # When a new comment is made it will be processed if its timestamp is more recent
    # than the one in the hash/yaml for this issue 

  def process_comment(comment, issue, notification_repo)
    last_comment_timestamp = @timestamps[issue.number] || 0  

    if last_comment_timestamp != 0 && last_comment_timestamp >= comment.updated_at
      return
    end

    # bot command or not, we need to update the yaml file so next time we 
    # pull in the comments we can skip this one.

    add_and_yaml_timestamps(issue.number, comment.updated_at)   
    lines = comment.body.split("\n")    
    lines.each do |line|
      process_command(line, notification_repo, issue)
    end
  end

  def process_command(line, notification_repo, issue)
    match = line.match(/^@cfme-bot\s+([-@a-z0-9_]+)\s+/i)
    return if !match

    command = match.captures.first
    command_value = match.post_match

    method_name = COMMANDS[command]
    if method_name.nil?

      # How to distinguish between the a typo in a command that needs reported back
      # to the user and just a regular comment that starts with @cfme-bot...?
      # client.add_comment(repo, issue.id, "invalid command #{command}, ignoring.")

      return
    else
      self.send(method_name, notification_repo, issue, command_value)
    end
  end


  def assign_to_issue(notification_repo, issue, assign_to_user)
    assign_to_user = assign_to_user.delete('@').rstrip
  
    # We cannot rely on rescuing the error Octokit::UnprocessableEntity
    # because assignee names unknown to manageiq might be valid in the 
    # global community..
    
    begin
      user = client.user(assign_to_user)
    rescue Octokit::NotFound
       add_assignee_comment(notification_repo, issue, assign_to_user)
       return
    end
    if check_user_organization(user)
      client.update_issue(notification_repo, issue.number, issue.title, issue.body, "assignee" => assign_to_user)
    else
      add_assignee_comment(notification_repo, issue, assign_to_user)
    end
  end

  def set_milestone(notification_repo, issue, milestone)  
    client.update_issue(notification_repo, issue.number, issue.title, issue.body, "milestone" => @milestones[milestone])
  end

  def check_user_organization(user)
    @organization_members.include?(user.login)
  end

  def load_organization_members
    @organization_members = Set.new

    members_array = client.organization_members(ORGANIZATION)
    members_array.collect do |members_hash|
      @organization_members.add(members_hash["login"])
    end
  end

  def remove_labels_from_issue(notification_repo, issue, command_value)
    message             = "Cannot remove the following label(s) because they are not recognized: "
    invalid_labels_bool = false
    valid_labels        = Array.new
    labels_array        = split(command_value)

    labels_array.each do |label|
      
      begin
        label = client.label(notification_repo, label.strip)
      rescue Octokit::NotFound
        message << " " << label << ","
        invalid_labels_bool = true    
        next
      end
      valid_labels.push(label)
    end

    if invalid_labels_bool
      client.add_comment(notification_repo, issue.number, message.chomp(','))
    end

    valid_labels.each do |valid_label|
      client.remove_label(notification_repo, issue.number, valid_label.name)  
    end
  end

  def add_assignee_comment(notification_repo, issue, assign_to_user)
    message = "Assignee #{assign_to_user} is an invalid user."
    client.add_comment(notification_repo, issue.number, message)
  end

  def add_labels_to_an_issue(notification_repo, issue, command_value)
    message = "Cannot apply the following label(s) because they are not recognized:"

    new_labels        = split(command_value)
    new_labels_length = new_labels.length
    allowed_labels    = Array.new


    new_labels.each do |new_label|
      new_label = new_label.strip

      if !check_permitted_label(new_label)
        message << " " << new_label << ","
        next
      else
        allowed_labels.push(new_label)
      end
    end

    if new_labels.length - allowed_labels.length > 0
      client.add_comment(notification_repo, issue.number, message.chomp(','))
    end

    if !allowed_labels.empty?
      client.add_labels_to_an_issue(notification_repo, issue.number, allowed_labels)
    end
  end

  def check_permitted_label(new_label)
    @permitted_labels.include?(new_label)
  end

  def mark_thread_as_read(thread_id)
    client.mark_thread_as_read(thread_id, "read" => false )
  end

  def split(labels)
    labels.split(", ")
  end

  def add_and_yaml_timestamps(key, updated_at)
    @timestamps[key]=updated_at
    File.open(ISSUE_MANAGER_YAML_FILE, 'w+') do |f| 
      YAML.dump(@timestamps, f) 
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

  def load_credentials_yaml_file
    begin
      @credentials = YAML.load_file(GITHUB_CREDENTIALS_YAML_FILE)
    rescue Errno::ENOENT
      logger.error("No #{GITHUB_CREDENTIALS_YAML_FILE} found. Exiting...")
      exit 1
    end 
  end
end

