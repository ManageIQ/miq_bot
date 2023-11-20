require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MiqBot
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    config.autoloader = :zeitwerk

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
