require 'thread'
require 'ruby_bugzilla'

class BugzillaService
  include ServiceMixin

  def initialize
    service # initialize the service
  end

  def service
    @service ||= begin
      bz = RubyBugzilla.new(*credentials.values_at("bugzilla_uri", "username", "password"))
      bz.login
      bz
    end
  end

  private

  def credentials
    @credentials ||= YAML.load_file(Rails.root.join('config/bugzilla_credentials.yml'))
  end
end
