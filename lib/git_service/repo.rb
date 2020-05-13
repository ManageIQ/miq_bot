module GitService
  class Repo
    def initialize(repo)
      @repo = repo
    end

    def commit(sha)
      GitService::Commit.new(rugged_repo, sha)
    end

    def git_fetch
      require 'rugged'
      rugged_repo.remotes.each do |remote|
        fetch_options = {}

        username = extract_username_from_git_remote_url(remote.url)
        fetch_options[:credentials] = Credentials.from_ssh_agent(username) if username

        rugged_repo.fetch(remote.name, fetch_options)
      end
    end

    private

    def rugged_repo
      @rugged_repo ||= Rugged::Repository.new(@repo.path.to_s)
    end

    def extract_username_from_git_remote_url(url)
      url.start_with?("http") ? nil : url.match(/^.+?(?=@)/).to_s.presence
    end
  end
end
