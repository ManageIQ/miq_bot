# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)

require 'rspec/rails'
require 'webmock/rspec'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  config.expect_with(:rspec) { |c| c.syntax = [:should, :expect] }

  config.include FactoryBot::Syntax::Methods

  require "awesome_spawn/spec_helper"
  config.include AwesomeSpawn::SpecHelper

  config.before do
    allow_any_instance_of(MinigitService).to receive(:service)
      .and_raise("Live execution is not allowed in specs.  Use stubs/expectations on service instead.")
  end

  config.after do
    Module.clear_all_cache_with_timeout

    # Disable rubocop check because .empty? doesn't exist on a Sidekiq Queue
    raise "miq_bot queue is not empty" unless Sidekiq::Queue.new("miq_bot").size == 0 # rubocop:disable Style/ZeroLengthPredicate
    raise "miq_bot_glacial queue is not empty" unless Sidekiq::Queue.new("miq_bot_glacial").size == 0 # rubocop:disable Style/ZeroLengthPredicate
  end
end

WebMock.disable_net_connect!(:allow_localhost => true)
