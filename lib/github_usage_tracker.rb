class GithubUsageTracker
  def self.record_datapoint
    new.record_datapoint
  end

  def self.rate_limit_measurements
    new.rate_limit_measurements
  end

  def rate_limit_measurements
    influxdb.query('SELECT * FROM rate_limit')
  end

  def record_datapoint
    # TODO: Clean this mess up
    client = Octokit::Client.new(:login => Settings.github_credentials.username, :password => Settings.github_credentials.password)
    influxdb.write_point('rate_limit', :values => { :requests_remaining_count => client.rate_limit!.remaining })
  end

  private

  def influxdb
    InfluxDB::Rails.client
  end
end
