module MiqToolsServices
  class Bugzilla
    include ServiceMixin

    class << self
      attr_accessor :credentials
    end
    delegate :credentials, :to => self

    def initialize
      service # initialize the service
    end

    def service
      @service ||= begin
        require 'active_bugzilla'
        bz = ActiveBugzilla::Service.new(
          credentials["bugzilla_uri"],
          credentials["username"],
          credentials["password"]
        )
        ActiveBugzilla::Base.service = bz
      end
    end

    def self.ids_in_git_commit_message(message)
      ids = []
      message.each_line.collect do |line|
        match = %r{^\s*https://bugzilla\.redhat\.com//?show_bug\.cgi\?id=(?<bug_id>\d+)$}.match(line)
        ids << match[:bug_id].to_i if match
      end
      ids
    end
  end
end
