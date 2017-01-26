class GithubUsageTracker
  def self.record_datapoint(**args)
    new.record_datapoint(args)
  end

  def self.rate_limit_measurements
    new.rate_limit_measurements
  end

  def rate_limit_measurements
    influxdb.query('SELECT * FROM rate_limit')
  end

  def record_datapoint(requests_remaining:, timestamp: nil)
    influxdb.write_point(
      'rate_limit',
      :values    => { :requests_remaining => requests_remaining.to_i },
      :timestamp => timestamp ? timestamp.to_i : Time.now.to_i
    )
  end

  private

  def influxdb
    InfluxDB::Rails.client
  end
end
