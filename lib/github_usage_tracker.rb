require 'uri'

class GithubUsageTracker
  def self.record_datapoint(**args)
    new.record_datapoint(args)
  end

  def self.influxdb
    @influx ||= InfluxDB::Client.new(Settings.influxdb.database_name,
                                     :username => Settings.influxdb.username,
                                     :password => Settings.influxdb.password,
                                     :time_precision => 'ns')
  end

  def record_datapoint(requests_remaining:, uri:)
    request_uri = URI.parse(uri).path.chomp("/")

    values = { :tags      => { :bot_version        => MiqBot.version },
               :values    => { :requests_remaining => requests_remaining.to_i, :uri => request_uri },
               :timestamp => DateTime.now.rfc3339(9) } # Near ns precision

    worker = worker_from_backtrace
    values[:tags].merge!(:worker => worker) if worker

    influxdb.write_point('github_api_request', values)
  rescue => e
    Rails.logger.info("#{e.class}: #{e.message}")
  end

  private

  def worker_from_backtrace
    caller.each do |l|
      match = /(?:app\/workers\/)(?:\w+\/)*?(\w+)(?:\.rb\:\d+)/.match(l)
      return match[1] if match && match[1].exclude?("_mixin")
    end
    nil
  end

  def influxdb
    self.class.influxdb
  end
end
