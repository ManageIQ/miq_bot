InfluxDB::Rails.configure do |config|
  config.influxdb_database = Settings.influxdb.database_name
  config.influxdb_username = Settings.influxdb.username
  config.influxdb_password = Settings.influxdb.password
end

# HACK: InfluxDB's Ruby and Rails clients have some issues with their logging strategy.
# Until the following Issues are resolved, we turn off the ridiculous amount of logging
# of background workers by nulling their log method.
#
# Logging from the background workers is constant and absolutely impossible to work with
# in the Rails console...
# * https://github.com/influxdata/influxdb-ruby/issues/180
#
# ...but you can't turn it off from here, cleanly.
# * https://github.com/influxdata/influxdb-rails/issues/35

InfluxDB::Writer::Async::Worker.include(
  Module.new {
    def log(level, message)
      # NOOP
    end
  }
)
