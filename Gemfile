source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 4.2.4'

# Use PostgreSQL as the database for Active Record
gem 'pg'

# InfluxDB for Github rate limit tracking
gem 'influxdb', '~>0.3.13'

# Use SCSS for stylesheets
gem 'sass-rails', '~> 4.0.0'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'

# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '~> 4.0.0'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer', :platforms => :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'

gem 'thin'
gem 'foreman', '~> 0.64.0' # v0.65.0 breaks support for the older upstart on RHEL 6

gem 'config'
gem 'listen'

# Sidekiq specific gems
gem 'sidekiq', '~> 4.1.1'
gem 'sidetiq', '~> 0.7.0'
gem 'sinatra', :require => false
gem 'slim'

# Services gems
gem 'active_bugzilla'
gem 'minigit',        '~> 0.0.4'
gem 'tracker_api',    '~> 1.6'
gem 'travis',         '~> 1.7.6'

gem 'awesome_spawn',        '>= 1.4.1'
gem 'default_value_for'
gem 'haml_lint',            '~> 0.20.0', :require => false
gem 'more_core_extensions', '~> 2.0.0',  :require => 'more_core_extensions/all'
gem 'rubocop',              '~> 0.47.0', :require => false
gem 'rugged',                            :require => false

gem 'octokit', '~> 4.6.0', :require => false
gem 'faraday', '~> 0.9.1'
gem 'faraday-http-cache', '~> 2.0.0'

group :development, :test do
  gem 'rspec'
  gem 'rspec-rails'
  gem 'timecop'
end

group :test do
  gem 'webmock'
  gem 'factory_girl_rails'
end
