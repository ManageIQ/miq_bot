require 'uri'

class GithubUsageTracker
  def self.record_datapoint(**args)
    new.record_datapoint(args)
  end

  def record_datapoint(requests_remaining:, uri:, timestamp: nil)
    request_uri = URI.parse(uri).path.chomp("/")

    influxdb.write_point(
      'github_api_request',
      { :tags      => { :bot_version        => MiqBot.version },
        :values    => { :requests_remaining => requests_remaining.to_i, :uri => request_uri },
        :timestamp => timestamp ? timestamp.to_i : Time.now.to_i }
    )
  rescue => e
    Rails.logger.info("#{e.class}: #{e.message}")
  end

  private

  def influxdb
    InfluxDB::Rails.client
  end
end
