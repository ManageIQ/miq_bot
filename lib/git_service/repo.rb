module GitService
  class Repo
    def initialize(repo)
      @repo = repo
    end

    def commit(sha)
      GitService::Commit.new(rugged_repo, sha)
    end

    def create_branch(name, from)
      rugged_repo.create_branch(name, from)
      GitService::Branch.new(::Branch.new(:repo => @repo, :name => name))
    end

    private

    def rugged_repo
      require 'rugged'
      @rugged_repo ||= Rugged::Repository.new(@repo.path.to_s)
    end
  end
end
