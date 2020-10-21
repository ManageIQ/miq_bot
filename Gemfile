source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.2.2'

# Use PostgreSQL as the database for Active Record
gem 'pg'

# InfluxDB for Github rate limit tracking
gem 'influxdb', '~>0.3.13'

# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0.7'

# Use jquery as the JavaScript library
gem 'jquery-rails'

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'

gem 'thin'
gem 'foreman', '~> 0.64.0' # v0.65.0 breaks support for the older upstart on RHEL 6

gem 'config'
gem 'listen'

# Sidekiq specific gems
gem 'sidekiq', '~> 5.2.5'
gem 'sidetiq', '~> 0.7.0'
gem 'sinatra', :require => false
gem 'slim'

# Services gems
gem 'minigit',        '~> 0.0.4'
gem 'tracker_api',    '~> 1.6'
gem 'travis',         '~> 1.7.6'

gem 'awesome_spawn',        '>= 1.4.1'
gem 'default_value_for',    '>= 3.1.0'
gem 'haml_lint',            '~> 0.28.0', :require => false
gem 'more_core_extensions', '~> 4.0.0',  :require => 'more_core_extensions/all'
gem 'rubocop',              '~> 0.69.0', :require => false
gem 'rubocop-performance',  '~> 1.3',    :require => false
gem 'rugged',                            :require => false

gem 'octokit', '~> 4.8.0', :require => false
gem 'faraday', '~> 0.9.2'
gem 'faraday-http-cache', '~> 2.0.0'

group :development, :test do
  gem 'rspec'
  gem 'rspec-rails'
  gem 'timecop'
end

group :test do
  gem 'factory_bot_rails'
  gem 'webmock'
end
