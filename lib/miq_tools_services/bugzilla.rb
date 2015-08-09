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
    MATCH_REGEX = /^((#{CLOSING_KEYWORDS.join("|")}):?)?\s*#{URL_REGEX}$/i

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

    # See https://www.bugzilla.org/docs/4.4/en/html/api/Bugzilla/WebService/Bug.html#search
    # for a list of find_options
    def find_bugs(find_options)
      ActiveBugzilla::Bug.find(find_options)
    end

    def self.ids_in_git_commit_message(message)
      ids = []
      message.each_line.collect do |line|
        match = MATCH_REGEX.match(line)
        ids << match[:bug_id].to_i if match
      end
      ids
    end
  end
end
