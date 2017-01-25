class GithubUsageTracker
  def self.record_datapoint
    new.record_datapoint
  end

  def record_datapoint
    # TODO Clean this mess up
    client = Octokit::Client.new(login: Settings.github_credentials.username, password: Settings.github_credentials.password)
    influxdb.write_point('github_requests_remaining', :tags => { :bot_sha => current_git_sha }, :values => { :count => client.rate_limit!.remaining })
  end

  private

  def current_git_sha
    @current_git_sha ||= `git rev-parse --short --verify HEAD`.strip
  end

  def influxdb
    InfluxDB::Rails.client
  end
end
