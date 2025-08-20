source 'https://rubygems.org'

# The Ruby version should match the lowest acceptable version of the application
ruby "~> 3.4.0"

plugin 'bundler-inject'
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

gem 'rails', '~> 8.0.2'

# Use PostgreSQL as the database for Active Record
gem 'pg'

# Use SCSS for stylesheets
gem 'sassc-rails'

# Use jquery as the JavaScript library
gem 'jquery-rails'

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'

gem 'foreman'
gem 'puma'

gem 'config'
gem 'listen'

# Sidekiq specific gems
gem 'sidecloq'
gem 'sidekiq'

# Services gems
gem 'minigit', '~> 0.0.4'
gem 'net-ssh', '~> 7.3'

gem 'awesome_spawn',        '~> 1.6'
gem 'default_value_for',    '~> 4.0'
gem 'haml_lint',            '~> 0.52', :require => false
gem 'irb'
gem 'manageiq-style',       '~> 1.5', ">=1.5.6", :require => false
gem 'more_core_extensions', '~> 4.4',  :require => 'more_core_extensions/all'
gem 'rugged',                          :require => false

gem 'faraday'
gem 'faraday-http-cache', '~> 2.5'
gem 'faraday-retry'
gem 'octokit', '~> 8.0', :require => false

group :development, :test do
  gem 'rspec'
  gem 'rspec-rails'
  gem 'simplecov', '>= 0.21.2'
  gem 'timecop'
end

group :test do
  gem 'factory_bot_rails'
  gem 'webmock'
end
