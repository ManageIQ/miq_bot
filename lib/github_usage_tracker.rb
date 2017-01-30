class GithubUsageTracker
  def self.record_datapoint(**args)
    new.record_datapoint(args)
  end

  def self.rate_limit_measurements
    new.rate_limit_measurements
  end

  ##
  # Returns rate limit measurements over the last 12 hours grouped by the
  # average of 1 minute intervals.
  #
  def rate_limit_measurements
    current_time = DateTime.now
    from_time    = current_time - 12.hours
    query = <<-eos
      SELECT MEAN(requests_remaining)
      FROM rate_limit
      WHERE time > '#{from_time.rfc3339}'
      AND time <= '#{current_time.rfc3339}'
      GROUP BY time(1m)
      fill(previous)
    eos

    influxdb.query(query)
  end

  def record_datapoint(requests_remaining:, timestamp: nil)
    influxdb.write_point(
      'rate_limit',
      { :tags      => { :bot_version        => MiqBot.version },
        :values    => { :requests_remaining => requests_remaining.to_i },
        :timestamp => timestamp ? timestamp.to_i : Time.now.to_i },
      nil, # Allow config to determine precision
      'twelve_weeks' # Retention policy
    )
  end

  private

  def influxdb
    InfluxDB::Rails.client
  end
end
