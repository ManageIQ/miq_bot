module GitHubApi
	class Organization
    attr_accessor :fq_repo_name, :repo, :client

    def initialize(octokit_org, user)
      @client = user.client
      @name = octokit_org.login
      load_organization_members
		end

    def member?(user)
      begin
        octokit_user = @client.user(user)
      rescue Octokit::NotFound
        return false
      end
      @organization_members.include?(octokit_user.login)
    end

    def get_repository(repo_name)
      @fq_repo_name  = "#{@name}/#{repo_name}"
      octokit_repo   = @client.repo(@fq_repo_name)
      @repo = Repo.new(octokit_repo, self)
    end

    private

    def load_organization_members
      @organization_members = Set.new
      octokit_members = @client.organization_members(@name)
      octokit_members.collect do |members_hash|
        @organization_members.add(members_hash["login"])
      end
    end
    
	end
end