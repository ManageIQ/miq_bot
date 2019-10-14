require 'set'

module GithubService
  class Issue < SimpleDelegator
    # https://developer.github.com/v3/issues

    WIP_REGEX = /^(?:\s*\[wip\])+/i

    def as_pull_request
      Issue.new(GithubService.pull_request(fq_repo_name, number))
    end

    def assign(user)
      GithubService.update_issue(fq_repo_name, number, "assignee" => user)
    end

    def add_reviewer(user)
      GithubService.request_pull_request_review(fq_repo_name, number, [user]) if pull_request?
    end

    def remove_reviewer(user)
      GithubService.delete_pull_request_review_request(fq_repo_name, number, "reviewers" => [user]) if pull_request?
    end

    def set_milestone(milestone)
      if GithubService.valid_milestone?(fq_repo_name, milestone)
        milestone_id = GithubService.milestones(fq_repo_name)[milestone]
        GithubService.update_issue(fq_repo_name, number, "milestone" => milestone_id)
      else
        false
      end
    end

    def add_comment(message)
      GithubService.add_comment(fq_repo_name, number, message)
    end

    def applied_label?(label_text)
      labels.include?(label_text)
    end

    # Note: This method creates labels on the repo if they don't exist,
    # and assumes that the labels being passed in have already been validated
    # if you don't want that behavior.
    #
    # For example, the notification monitor responds to users about any labels
    # being requested to be added that aren't valid, before calling this method.
    #
    def add_labels(requested_labels_to_add)
      actual_labels_to_add = []

      Array(requested_labels_to_add).uniq.each do |label|
        actual_labels_to_add << label if labels.add?(label)
      end

      return false if actual_labels_to_add.empty?
      wipify_title if actual_labels_to_add.include?("wip")

      # GithubService itself uses this method to override the Octokit method.
      # Do NOT use the raw service like this under normal circumstances.
      GithubService.send(:service).add_labels_to_an_issue(fq_repo_name, number, actual_labels_to_add)
    end
    alias add_label add_labels

    def remove_label(label_to_remove)
      return false unless labels.delete?(label_to_remove)
      unwipify_title if label_to_remove.include?("wip")

      # GithubService itself uses this method to override the Octokit method.
      # Do NOT use the raw service like this under normal circumstances.
      GithubService.send(:service).remove_label(fq_repo_name, number, label_to_remove)
    end

    def author
      user.login
    end

    def pull_request?
      respond_to?(:pull_request)
    end

    # Overrides Octokit response key
    # We manage this ourselves for the life of the issue object to avoid making
    # extra API calls.
    def labels
      @labels ||= Set.new(__getobj__.labels.map(&:name))
    end

    def fq_repo_name
      @fq_repo_name ||= repository_url.match(/repos\/([^\/]+\/[^\/]+)\z/)[1]
    end

    def organization_name
      @organization_name ||= fq_repo_name.split("/")[0]
    end

    def repo_name
      @repo_name ||= fq_repo_name.split("/")[1]
    end

    private

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

    def update(options)
      GithubService.update_issue(fq_repo_name, number, options)
    end
  end
end
