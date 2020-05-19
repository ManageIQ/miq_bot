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

        username = uri_for_remote(remote.url).user
        fetch_options[:credentials] = Credentials.from_ssh_agent(username) if username

        rugged_repo.fetch(remote.name, fetch_options)
      end
    end

    private

    def rugged_repo
      @rugged_repo ||= Rugged::Repository.new(@repo.path.to_s)
    end

    def uri_for_remote(url)
      @remote_uris      ||= {}
      @remote_uris[url] ||= begin
                              if url.start_with?("http", "ssh://")
                                URI(url)
                              elsif url.match?(/\A[-\w:.]+@.*:/) # exp: git@github.com:org/repo
                                URI(url.sub(':', '/').prepend("ssh://"))
                              end
                            end
    end
  end
end
