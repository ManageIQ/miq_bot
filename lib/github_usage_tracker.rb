class GithubUsageTracker
  def self.record_datapoint
    new.record_datapoint
  end

  def self.requests_remaining_measurements
    new.requests_remaining_measurements
  end

  def requests_remaining_measurements
    influxdb.query('SELECT * FROM github_requests_remaining')
  end

  def record_datapoint
    # TODO: Clean this mess up
    client = Octokit::Client.new(:login => Settings.github_credentials.username, :password => Settings.github_credentials.password)
    influxdb.write_point('github_requests_remaining', :values => { :count => client.rate_limit!.remaining })
  end

  private

  def influxdb
    InfluxDB::Rails.client
  end
end
