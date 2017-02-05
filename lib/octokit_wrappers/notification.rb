module OctokitWrappers
  class Notification < SimpleDelegator
    # https://developer.github.com/v3/activity/notifications/

    def mark_thread_as_read
      Octokit.mark_thread_as_read(thread_id, "read" => false)
    end

    def issue_number
      subject.url.match(/[0-9]+\Z/).to_s
    end

    private

    def thread_id
      url.match(/[0-9]+\Z/).to_s
    end
  end
end
