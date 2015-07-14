module MiqToolsServices
  class Bugzilla
    include ServiceMixin

    CLOSING_KEYWORDS = %w(
      close
      closes
      closed
      fix
      fixes
      fixed
      resolve
      resolves
      resolved
    )

    URL_REGEX = %r{https://bugzilla\.redhat\.com//?show_bug\.cgi\?id=(?<bug_id>\d+)}

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
        match = /^(#{CLOSING_KEYWORDS.join("|")})?\s*#{URL_REGEX}$/i.match(line)
        ids << match[:bug_id].to_i if match
      end
      ids
    end
  end
end
