require 'octokit'
require_relative 'comment'
require_relative 'notification'
require_relative 'repo'
require_relative 'milestone'
require_relative 'issue'
require_relative 'label'
require_relative 'organization.rb'
require_relative 'user.rb'
require_relative '../logging'

include Logging

module GitHubApi

  def self.connect(username, password)
    @user           = GitHubApi::User.new
    @user.client ||= Octokit::Client.new(:login => username, :password => password, :auto_traversal => true)

    return @user
  end
end
