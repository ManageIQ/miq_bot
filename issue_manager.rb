#!/usr/bin/env ruby
require 'bundler/setup'
require 'octokit'
require 'yaml'
require 'time'
SLEEPTIME = 5


class IssueManager

  def initialize
    @client = Octokit::Client.new(:login => "xxxxxx", :password => "xxxxxx")
    @timestamps = load_yaml_file
    if !@timestamps
      @timestamps = Hash.new(0)
    end
    @commands = ["add_label", "rm_label", "remove_label", "assign"]    
  end

  def print_issue(issue)
    puts "Title:\t #{issue.title}"
    puts "Body:\t #{issue.body}"
    puts "Number:\t #{issue.number}"
    puts "State:\t #{issue.state}"
  end


  def add_label(issue_id, labels)
    @client.add_labels_to_an_issue("ManageIQ/sandbox", issue_id, labels)
  end

  def remove_label(issue_id, label)
    @client.remove_label("ManageIQ/sandbox", issueID, label)
  end

  def get_issue_comments(issue_id)
    puts "issue id #{issueID}"
    @client.issue_comments("ManageIQ/sandbox", issue_id)
  end

  def find_issue(repository, issue_id)
    @client.issue("ManageIQ/#{repository}", issue_id)
  end

  def print_notification(notification)
    puts "Notification repo: #{notification.repository.name}"
    puts "Notification subject title: #{notification.subject.title}"
    #puts "#{notification.subject.url}"
    #puts "#{notification.subject.latest_comment_url}"
  end

  def print_comment(comment)
    puts "\tComment body: #{comment.body}"
    puts "\tComment added at: #{comment.updated_at}\n"
  end

  def get_notifications
    puts "get_notifcatons"
    notifications = @client.repository_notifications("ManageIQ/sandbox", "all" => false)
    puts "#{notifications.count}"
    notifications.each do |notification|
      process_notification(notification)
    end
  end

  def extract_comment_id(notification)
    notification.subject.latest_comment_url.match(/[0-9]+\Z/)
  end

  def extract_issue_id(notification)
    notification.subject.url.match(/[0-9]+\Z/)
  end

  def make_repo_name(notification)
    "ManageIQ/#{notification.repository.name}"
  end

  def process_notification(notification)
    print_notification(notification)
    repo        = make_repo_name(notification)
    issue_id    = extract_issue_id(notification)
    issue       = @client.issue(repo, issue_id)
    #puts "Issue: #{print_issue(issue)}"
    comments    = @client.issue_comments(repo, issue_id)
    puts "comments #{comments.count}"
    comments.each do |comment|
      process_comment(comment, issue, repo) 
    end
  end

  

    # comment: The goal is to find the comments that have not been processed by the BOT. 
    # As each comment is processed it overwrites the entry in the hash @timestamps and yaml file
    # for this issue.
    # When a new comment is made it will be processed if its timestamp is more recent
    # than the one in the hash/yaml for this issue-comment 

  def process_comment(comment, issue, repo)
    last_comment_timestamp = @timestamps[issue.number] || 0   
    if last_comment_timestamp != 0 && last_comment_timestamp >= comment.updated_at
      return
    end

    puts "New comment: #{comment.body}"

    @commands.each do |command|
      command_value = parse_command_value(comment, command)
      if command_value.empty?
        puts "empty command value for #{command}, ignoring..."
        next
      end
      command_value.delete!(' ')
      case command
        when "add_label" then
          labels_array = chomp_and_split(command_value)
          #puts "labels array #{labels_array}"
          @client.add_labels_to_an_issue(repo, issue.number, labels_array)

        when "rm_label", "remove_label" then

          labels_array = chomp_and_split(command_value)

          puts labels_array
          labels_array.each do |label|
                      puts label

            @client.remove_label(repo, issue.number, label)
          end

        when "assign" then
          new_assignee = command_value.strip.delete('@')
          puts "new assignee: #{new_assignee}"
          @client.update_issue(repo, issue.number, issue.title, issue.body, "assignee" => new_assignee)

          #issue = @client.issue(repo, issue.number)
          #updated_assignee = issue.assignee.login
          #puts "updated assignee #{updated_assignee}"

          #if updated_assignee != new_assignee
           #   @client.update_comment(repo, comment.id, "assignee mismatch. Updated assignee is #{updated_assignee} ")
          #end
      end

      # Store in the yaml file            
      add_and_yaml_timestamps(issue.number, comment.updated_at)       
    end
  end

  def parse_command_value(comment, command_name)
    #puts "Looking for command in comment #{command_name}"
    command_value = "" 
    match = comment.body.match(/@cfme-bot #{command_name}/)
    if match   
      command_value = match.post_match
    end
    return command_value
  end


  def chomp_and_split(labels)
    labels.chomp.delete(' ').split(",")
  end

  def add_and_yaml_timestamps(key, updated_at)
    @timestamps[key]=updated_at
    File.open("issue_manager.yml", 'w+') do |f| 
      YAML.dump(@timestamps, f) 
    end
  end

  def load_yaml_file
    @timestamps = YAML.load_file('issue_manager.yml')
  end
end
 
issue_manager = IssueManager.new
loop {
  issue_manager.get_notifications
  sleep(SLEEPTIME)
}