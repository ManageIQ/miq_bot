require_relative 'git_hub_api'

module GitHubApi
  class Repo
    attr_accessor :fq_repo_name, :milestones, :client

    def initialize(octokit_repo, organization)
      @fq_repo_name   = organization.fq_repo_name
      @client = organization.client
      load_milestones
    end

    def notifications
      @notifications = begin
        octokit_notifications = GitHubApi.execute(@client, :repository_notifications, @fq_repo_name, "all" => false)
        octokit_notifications.collect do |octokit_notification|
          Notification.new(octokit_notification, self)
        end
      end
    end

    def labels
      @labels ||= begin
        repo_labels = GitHubApi.execute(@client, :labels, @fq_repo_name)
        Set.new.tap { |set| repo_labels.each { |l| set.add(l.name) } }
      end
    end

    def valid_label?(label_text)
      labels.include?(label_text)
    end

    def refresh_labels
      @labels = nil
    end

    def valid_milestone?(milestone)
      milestones.include?(milestone)
    end

    private

    def load_milestones
      @milestones = Hash.new
      octokit_milestones = GitHubApi.execute(@client, :list_milestones, @fq_repo_name)
      octokit_milestones.each do |octokit_milestone|
        milestone = Milestone.new(octokit_milestone, self)
        @milestones[milestone.title] = milestone.number
      end
    end
  end
end
