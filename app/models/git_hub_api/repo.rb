module GitHubApi
  class Repo
    attr_accessor :client, :fq_repo_name

    def initialize(client, fq_repo_name)
      @client = client
      @fq_repo_name = fq_repo_name
    end

    def notifications
      @notifications = begin
        octokit_notifications = GitHubApi.execute(@client, :repository_notifications, @fq_repo_name, "all" => false)
        octokit_notifications.collect do |octokit_notification|
          Notification.new(octokit_notification, self)
        end
      end
    end

    def self.labels_cache
      @labels_cache ||= {}
    end

    def labels
      self.class.labels_cache[fq_repo_name] ||= begin
        repo_labels = GitHubApi.execute(@client, :labels, @fq_repo_name)
        Set.new(repo_labels.collect(&:name))
      end
    end

    def valid_label?(label_text)
      labels.include?(label_text)
    end

    def refresh_labels
      self.class.labels_cache.delete(fq_repo_name)
    end

    def self.milestones_cache
      @milestones_cache ||= {}
    end

    def milestones
      self.class.milestones_cache[fq_repo_name] ||= begin
        repo_milestones = GitHubApi.execute(@client, :list_milestones, @fq_repo_name)
        Hash[repo_milestones.collect { |m| [m.title, m.number] }]
      end
    end

    def valid_milestone?(milestone)
      milestones.include?(milestone)
    end

    def refresh_milestones
      self.class.milestones_cache.delete(fq_repo_name)
    end

    def self.assignees_cache
      @assignees_cache ||= {}
    end

    def assignees
      self.class.assignees_cache[fq_repo_name] ||= begin
        repo_assignees = GitHubApi.execute(@client, :repo_assignees, @fq_repo_name)
        Set.new(repo_assignees.collect(&:login))
      end
    end

    def valid_assignee?(user)
      assignees.include?(user)
    end

    def refresh_assignees
      self.class.assignees_cache.delete(fq_repo_name)
    end
  end
end
