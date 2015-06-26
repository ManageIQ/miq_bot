module GitHubApi
  class Organization
    attr_accessor :fq_repo_name, :repo, :client

    def initialize(octokit_org, user)
      @client = user.client
      @name = octokit_org.login
    end

    def members
      @members ||= begin
        org_members = GitHubApi.execute(@client, :organization_members, @name)
        Set.new.tap { |set| org_members.each { |m| set.add[m["login"]] } }
      end
    end

    def member?(user)
      members.include?(user)
    end

    def refresh_members
      @members = nil
    end

    def get_repository(repo_name)
      @fq_repo_name  = "#{@name}/#{repo_name}"
      octokit_repo   = GitHubApi.execute(@client, :repo, @fq_repo_name)
      @repo = Repo.new(octokit_repo, self)
    end
  end
end
