require 'set'

module OctokitWrappers
  class Issue < SimpleDelegator
    # https://developer.github.com/v3/issues

    def list_comments
      @comments ||= Octokit.issue_comments(fq_repo_name, number)
    end

    def assign(user)
      update("assignee" => user)
    end

    def set_milestone(milestone)
      update("milestone" => milestone)
    end

    def add_comment(message)
      Octokit.add_comment(fq_repo_name, number, message)
    end

    def applied_label?(label_text)
      applied_labels.include?(label_text)
    end

    def add_labels(labels)
      labels = Array(labels).uniq
      applied_labels << labels
      Octokit.add_labels_to_an_issue(fq_repo_name, number, labels)
    end
    alias :add_label :add_labels

    def remove_labels(labels)
      labels = Array(labels).uniq
      applied_labels.subtract(labels)
      Octokit.replace_all_labels(fq_repo_name, number, applied_labels)
    end
    alias :remove_label :remove_labels

    private

    def fq_repo_name
      @fq_repo_name ||= repository_url.match(/repos\/(\w\/\w)\z/)[1]
    end

    def update(options)
      Octokit.update_issue(fq_repo_name, number, title, body, options)
    end

    def applied_labels
      @applied_labels ||= begin
        labels = Octokit.labels_for_issue(fq_repo_name, number).map(&:name)
        Set.new(labels)
      end
    end
  end
end
