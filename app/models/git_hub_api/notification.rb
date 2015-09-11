module GitHubApi
  class Notification
    def initialize(octokit_notification, repo)
      @repo           = repo
      @repo_name      = repo.fq_repo_name
      @issue_id       = extract_issue_id(octokit_notification)
      @thread_id      = extract_thread_id(octokit_notification)
      @client         = repo.client
    end

    def issue
      octokit_issue   = GitHubApi.execute(@client, :issue, @repo_name, @issue_id)
      issue           = Issue.new(octokit_issue, @repo)
    end

    def mark_thread_as_read
      GitHubApi.execute(@client, :mark_thread_as_read, @thread_id, "read" => false)
    end

    private

    def extract_issue_id(octokit_notification)
      octokit_notification.subject.url.match(/[0-9]+\Z/).to_s
    end

    def extract_thread_id(octokit_notification)
      octokit_notification.url.match(/[0-9]+\Z/).to_s
    end

    def print_notification(notification)
      logger.info("Notification repo: #{notification.repository.name}")
      logger.info("Notification subject title: #{notification.subject.title}")
    end
  end
end
