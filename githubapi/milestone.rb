require_relative 'git_hub_api'

module GitHubApi
  class Milestone
    attr_accessor :title, :number

  	def initialize(octokit_milestone, repo)
      @title  = octokit_milestone.title
      @number = octokit_milestone.number
      @repo   = repo
    end
  end
end
