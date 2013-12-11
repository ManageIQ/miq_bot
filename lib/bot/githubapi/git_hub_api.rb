require 'octokit'
require 'benchmark'
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
    @user = GitHubApi::User.new
    @user.client ||= Octokit::Client.new(:login => username, :password => password, :auto_traversal => true)

    return @user
  end

  def self.execute(client, cmd, *args)
    rate_limit_remaining = client.rate_limit_remaining
    logger.debug("Executing #{cmd} #{args.inspect}...api calls remaining #{rate_limit_remaining}")
    val = nil
    t = Benchmark.realtime { val = client.send(cmd, *args) }
    logger.debug("Executing #{cmd} #{args.inspect}...Completed in #{t}s and used #{rate_limit_remaining - client.rate_limit_remaining} api calls")
    val
  rescue => err
    logger.error("Executing #{cmd} #{args.inspect}...Failed in #{t}s")
    logger.error("#{err.class}: #{err}")
    logger.error(err.backtrace.join("\n"))
    raise
  end
end
