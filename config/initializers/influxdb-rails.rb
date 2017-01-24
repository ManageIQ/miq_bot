InfluxDB::Rails.configure do |config|
  config.influxdb_database = "miq_bot_#{Rails.env}"
  config.influxdb_username = ENV['INFLUX_USERNAME']
  config.influxdb_password = ENV['INFLUX_PASSWORD']
end
