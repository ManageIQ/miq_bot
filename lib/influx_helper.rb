module InfluxHelper
  class << self
    # TODO Checks for proper user authentication
    # NOTE InfluxDB installs with authentication OFF by default!

    def ensure_database_exists!(database_name = InfluxDB::Rails.configuration.influxdb_database)
      raise "InfluxDB database '#{database_name}' not found." unless database_exists?(database_name)
    end

    def database_exists?(database_name = InfluxDB::Rails.configuration.influxdb_database)
      InfluxDB::Rails.client.list_databases.any? { |db| db['name'] == database_name }
    end
  end
end

