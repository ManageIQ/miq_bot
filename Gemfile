source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.0.2'

# Use PostgreSQL as the database for Active Record
gem 'pg'

# Use SCSS for stylesheets
gem 'sass-rails', '~> 4.0.0'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'

# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '~> 4.0.0'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'

gem 'thin'
gem 'foreman', '~> 0.64.0' # v0.65.0 breaks support for the older upstart on RHEL 6

# Sidekiq specific gems
gem 'sidekiq', '~> 2.17'
gem 'sidetiq'
gem 'sinatra', require: false
gem 'slim'

gem 'cfme_tools_services', :path => "../cfme_tools_services"

gem 'awesome_spawn'
gem 'default_value_for'
gem 'more_core_extensions', :require => 'more_core_extensions/all'
gem 'rubocop', '>= 0.21.0'

group :development, :test do
  gem 'rspec'
  gem 'rspec-rails'
  gem 'timecop'
end

group :issue_manager do
  gem 'octokit',       '~> 1.25.0'
  gem 'minigit',       '~> 0.0.4'

  # Lock down dependency
  gem 'faraday', '~> 0.8.8'
end
