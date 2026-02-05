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
        username      = uri_for_remote(remote.url).user
        hostname      = uri_for_remote(remote.url).hostname
        credentials   = Credentials.find_for_user_and_host(username, hostname)

        fetch_options[:credentials] = credentials if credentials

        rugged_repo.fetch(remote.name, **fetch_options)
      end
    end

    private

    def rugged_repo
      @rugged_repo ||= Rugged::Repository.new(@repo.path.to_s)
    end

    def uri_for_remote(url)
      @remote_uris      ||= {}
      @remote_uris[url] ||=
        if url.start_with?("http", "ssh://")
          URI(url)
        elsif url.match?(/\A[-\w:.]+@.*:/) # exp: git@github.com:org/repo
          URI(url.sub(':', '/').prepend("ssh://"))
        end
    end
  end
end
