module GitHubApi
  class Organization
    attr_accessor :name, :client

    def initialize(octokit_org, user)
      @client = user.client
      @name = octokit_org.login
    end

    def get_repository(repo_name)
      fq_repo_name = "#{@name}/#{repo_name}"
      GitHubApi::Repo.new(self, fq_repo_name)
    end
  end
end
