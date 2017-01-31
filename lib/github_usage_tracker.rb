class GithubUsageTracker
  def self.record_datapoint(**args)
    new.record_datapoint(args)
  end

  def record_datapoint(requests_remaining:, timestamp: nil)
    influxdb.write_point(
      'rate_limit',
      { :tags      => { :bot_version        => MiqBot.version },
        :values    => { :requests_remaining => requests_remaining.to_i },
        :timestamp => timestamp ? timestamp.to_i : Time.now.to_i }
    )
  rescue => e
    logger.info("#{e.name}: #{e.message}")
  end

  private

  def influxdb
    InfluxDB::Rails.client
  end
end
