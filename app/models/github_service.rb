require 'thread'
require 'github_api'

class GithubService
  include ServiceMixin

  def self.configure
    return if @configured

    Github.configure do |config|
      config.login           = credentials["username"]
      config.password        = credentials["password"]
      config.auto_pagination = true
    end

    @configured = true
  end

  def initialize(options)
    @options = options.dup

    if @options[:repo].kind_of?(CommitMonitorRepo)
      @options[:user] = @options[:repo].upstream_user
      @options[:repo] = @options[:repo].name
    end

    service # initialize the service
  end

  def service
    @service ||= begin
      self.class.configure
      Github.new(@options)
    end
  end

  private

  def self.credentials
    @credentials ||= YAML.load_file(Rails.root.join('config/github_credentials.yml'))
  end

  private_class_method :credentials
end
