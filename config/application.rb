require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module MiqBot
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.eager_load_paths << Rails.root.join("app/workers/concerns")
    config.eager_load_paths << Rails.root.join("lib/github_service/concerns")
    config.eager_load_paths << Rails.root.join("lib")

    # Use yaml_unsafe_load for column serialization to handle Symbols
    config.active_record.use_yaml_unsafe_load = true

    console do
      TOPLEVEL_BINDING.eval('self').extend(ConsoleMethods)
    end
  end
end
