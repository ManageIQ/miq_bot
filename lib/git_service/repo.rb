module GitService
  class Repo
    def initialize(repo)
      @repo = repo
    end

    def commit(sha)
      GitService::Commit.new(rugged_repo, sha)
    end

    private

    def rugged_repo
      @rugged_repo ||= Rugged::Repository.new(@repo.path.to_s)
    end
  end
end
