require 'travis'

# A helper class for making v3 API class to the TravisCI API, since the current
# API mostly only makes v2 calls, and does a decent amount of inificient ones
# at that...
#
# Expects for most calls that a base Travis::Entity has been set for the given
# client call.  Passed in as a hash during initialization.
#
class TravisV3Client
  attr_reader :connection, :repo, :user_agent

  def initialize(base_entities = {})
    @connection = Faraday.new(:url => Travis::Client::ORG_URI)

    @connection.headers['Authorization']      = "token #{::Settings.travis.access_token}"
    @connection.headers['travis-api-version'] = '3'

    @repo = base_entities[:repo]

    set_user_agent
  end

  def repo_branch_builds(branch = "master", params = {})
    query_params = {
      "branch.name"      => branch,
      "build.event_type" => "push,api,cron"
    }.merge(params)

    data = connection.get("/repo/#{repo.id}/builds", query_params)
    repo.session.load(JSON.parse(data.body))["builds"]
  end

  private

  # Use the Travis user agent for this
  def set_user_agent
    base_model = repo
    if base_model
      agent_string = repo.session.headers['User-Agent']
      @connection.headers['User-Agent'] = agent_string
      agent_string
    end
  end
end
