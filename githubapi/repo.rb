require_relative 'git_hub_api'

module GitHubApi
  
  class Repo

    attr_accessor :fq_repo_name, :milestones, :labels, :client

    def initialize(octokit_repo, organization, client)
      @fq_repo_name   = organization.fq_repo_name
      @client = client
      load_milestones
      load_valid_labels
    end

    def notifications
      @notifications ||= begin
        octokit_notifications = @client.repository_notifications(@fq_repo_name, "all" => false)        
        octokit_notifications.collect do |octokit_notification|
          Notification.new(octokit_notification, self)
        end
      end
    end

    def valid_label?(label_text)
      @labels.include?(label_text)
    end

    def valid_milestone?(milestone)
      milestones.include?(milestone)
    end 

    private

    def load_valid_labels
      @labels     = Set.new
      repo_labels = @client.labels(@fq_repo_name)
      repo_labels.each do |label|
        @labels.add(label.name)
      end
    end
 
    def load_milestones
      @milestones = Hash.new
      octokit_milestones = @client.list_milestones(@fq_repo_name)
      octokit_milestones.each do |octokit_milestone|
        milestone = Milestone.new(octokit_milestone, self)
        @milestones[milestone.title] = milestone.number
      end
    end
  end
end

