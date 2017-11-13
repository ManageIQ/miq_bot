module GithubService
  class Notification < SimpleDelegator
    # https://developer.github.com/v3/activity/notifications/

    def mark_thread_as_read
      GithubService.mark_thread_as_read(thread_id, "read" => false)
    end

    def issue_number
      subject.url.match(/\/([0-9]+)\Z/).try(:[], 1)
    end

    private

    def thread_id
      url.match(/[0-9]+\Z/).to_s
    end
  end
end
