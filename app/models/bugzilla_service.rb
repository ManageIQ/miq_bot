require 'thread'
require 'ruby_bugzilla'

module BugzillaService
  def self.call
    raise "no block given" unless block_given?
    synchronize do
      bz = RubyBugzilla.new(*credentials.values_at("bugzilla_uri", "username", "password"))
      bz.login
      yield bz
    end
  end

  private

  def self.mutex
    @mutex ||= Mutex.new
  end

  def self.synchronize
    mutex.synchronize { yield }
  end

  def self.credentials
    @credentials ||= YAML.load_file(Rails.root.join('config/bugzilla_credentials.yml'))
  end

  private_class_method :mutex, :synchronize, :credentials
end
