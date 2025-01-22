require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MiqBot
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.eager_load_paths << Rails.root.join("app/workers/concerns").to_s
    config.eager_load_paths << Rails.root.join("lib/github_service/concerns").to_s
    config.eager_load_paths << Rails.root.join("lib").to_s

    # Use yaml_unsafe_load for column serialization to handle Symbols
    config.active_record.use_yaml_unsafe_load = true

    console do
      TOPLEVEL_BINDING.eval('self').extend(ConsoleMethods)
    end
  end

  def self.version
    @version ||= `GIT_DIR=#{Rails.root.join('.git')} git describe --tags`.chomp
  end
end
