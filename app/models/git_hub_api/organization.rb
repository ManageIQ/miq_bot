module GitHubApi
  class Organization
    attr_accessor :name, :client

    def initialize(octokit_org, user)
      @client = user.client
      @name = octokit_org.login
    end

    def self.members_cache
      @members_cache ||= {}
    end

    def members
      self.class.members_cache[name] ||= begin
        org_members = GitHubApi.execute(@client, :organization_members, @name)
        Set.new.tap { |set| org_members.each { |m| set.add(m["login"]) } }
      end
    end

    def member?(user)
      members.include?(user)
    end

    def refresh_members
      self.class.members_cache.delete(name)
    end

    def get_repository(repo_name)
      fq_repo_name = "#{@name}/#{repo_name}"
      octokit_repo = GitHubApi.execute(@client, :repo, fq_repo_name)
      GitHubApi::Repo.new(octokit_repo, self, fq_repo_name)
    end
  end
end
