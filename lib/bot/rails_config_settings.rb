CONFIG_DIR = File.join(File.dirname(__FILE__), '../../config')
ENV["RAILS_ENV"] ||= "development"

require 'rails_config'
RailsConfig.setup do |config|
  config.const_name = "Settings"
  config.load_and_set_settings(
    config.setting_files(CONFIG_DIR, ENV["RAILS_ENV"])
  )
end
