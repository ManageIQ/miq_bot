require 'set'

module OctokitWrappers
  class Repository < DelegateClass(Octokit::Repository)
    # http://www.rubydoc.info/gems/octokit/Octokit/Repository

    def initialize(*args)
      super(Octokit::Repository.new(*args))
    end

    class << self
      def labels_cache
        @labels_cache ||= {}
      end

      def milestones_cache
        @milestones_cache ||= {}
      end

      def assignees_cache
        @assignees_cache ||= {}
      end
    end

    def fq_name
      @fq_name ||= "#{owner}/#{name}"
    end

    def notifications
      Octokit.repository_notifications(fq_name, "all" => false).map do |notification|
        OctokitWrappers::Notification.new(notification)
      end
    end

    def labels
      self.class.labels_cache[fq_name] ||= begin
        repo_labels = Octokit.labels(fq_name)
        Set.new(repo_labels.collect(&:name))
      end
    end

    def valid_label?(label_text)
      labels.include?(label_text)
    end

    def refresh_labels
      self.class.labels_cache.delete(fq_name)
    end

    def milestones
      self.class.milestones_cache[fq_name] ||= begin
        repo_milestones = Octokit.list_milestones(fq_name)
        Hash[repo_milestones.map { |m| [m.title, m.number] }]
      end
    end

    def valid_milestone?(milestone)
      milestones.include?(milestone)
    end

    def refresh_milestones
      self.class.milestones_cache.delete(fq_name)
    end

    def assignees
      self.class.assignees_cache[fq_name] ||= begin
        repo_assignees = Octokit.repo_assignees(fq_name)
        Set.new(repo_assignees.collect(&:login))
      end
    end

    def valid_assignee?(user)
      assignees.include?(user)
    end

    def refresh_assignees
      self.class.assignees_cache.delete(fq_name)
    end
  end
end
