require_relative 'git_hub_api'

module GitHubApi
  class User
    attr_accessor :username, :password, :client

    def initialize
    end

    def find_organization(organization_name)
      octokit_org = GitHubApi.execute(@client, :organization, organization_name)
      @organization  = Organization.new(octokit_org, self)
    end
  end
end
