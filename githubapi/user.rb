require_relative 'git_hub_api'

module GitHubApi

  class User

    ORGANIZATION = "ManageIQ"
    attr_accessor :username, :password, :client

    def initialize
    end

    def get_organization
      octokit_org = @client.organization(ORGANIZATION)
      @organization  = GitHubApi::Organization.new(octokit_org, self, @client)
    end
  end
end
