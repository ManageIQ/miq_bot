class GithubUsageTracker
  def self.record_datapoint
    new.record_datapoint
  end

  def record_datapoint
    InfluxHelper.ensure_database_exists!
    # TODO Clean this mess up
    client = Octokit::Client.new(login: Settings.github_credentials.username, password: Settings.github_credentials.password)
    influxdb.write_point('api_requests_remaining', :values => { :count => client.rate_limit!.remaining })
  end

  private

  def influxdb
    InfluxDB::Rails.client
  end
end
