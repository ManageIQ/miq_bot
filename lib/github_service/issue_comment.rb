module GithubService
  class IssueComment < SimpleDelegator
    # https://developer.github.com/v3/issues

    def author
      user.login
    end
  end
end
