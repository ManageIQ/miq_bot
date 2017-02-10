require 'set'

module GithubService
  class Issue < SimpleDelegator
    # https://developer.github.com/v3/issues

    WIP_REGEX = /^(?:\s*\[wip\])+/i

    def assign(user)
      GithubService.update_issue(fq_repo_name, number, "assignee" => user)
    end

    def set_milestone(milestone)
      GithubService.update_issue(fq_repo_name, number, "milestone" => milestone)
    end

    def add_comment(message)
      GithubService.add_comment(fq_repo_name, number, message)
    end

    def applied_label?(label_text)
      applied_labels.include?(label_text)
    end

    def add_labels(labels)
      labels = Array(labels).uniq
      GithubService.add_labels_to_an_issue(fq_repo_name, number, labels)
      applied_labels << labels
      wipify_title if labels.include?("wip")
    end
    alias add_label add_labels

    def remove_labels(labels)
      labels = Array(labels).uniq
      applied_labels.subtract(labels)
      GithubService.replace_all_labels(fq_repo_name, number, applied_labels)
      unwipify_title if labels.include?("wip")
    end
    alias remove_label remove_labels

    def author
      user.login
    end

    private

    def fq_repo_name
      @fq_repo_name ||= repository_url.match(/repos\/(\w+\/\w+)\z/)[1]
    end

    def applied_labels
      @applied_labels ||= begin
        labels = Octokit.labels_for_issue(fq_repo_name, number).map(&:name)
        Set.new(labels)
      end
    end

    def wipify_title
      if title !~ WIP_REGEX
        update(:title => "[WIP] #{title}")
      end
    end

    def unwipify_title
      if (match = title.match(WIP_REGEX))
        update(:title => match.post_match.lstrip)
      end
    end
  end
end
