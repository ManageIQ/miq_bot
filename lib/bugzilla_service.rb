class BugzillaService
  include ThreadsafeServiceMixin

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

  def initialize
    service # initialize the service
  end

  def service
    @service ||= begin
      require 'active_bugzilla'
      bz = ActiveBugzilla::Service.new(*credentials.to_h.values_at(:url, :username, :password))
      ActiveBugzilla::Base.service = bz
    end
  end

  def find_bug(id)
    ActiveBugzilla::Bug.find(:product => Settings.bugzilla.product, :id => id).first
  end

  def with_bug(id)
    yield find_bug(id)
  end

  def self.ids_in_git_commit_message(message)
    search_in_message(message).collect { |bug| bug[:bug_id] }
  end

  def self.search_in_message(message)
    return [] unless Settings.bugzilla_credentials.url

    regex = match_regex

    message.each_line.collect do |line|
      match = regex.match(line.strip)
      match && Hash[match.names.zip(match.captures)].tap do |h|
        h.symbolize_keys!
        h[:bug_id]     &&= h[:bug_id].to_i
        h[:resolution] &&= h[:resolution].downcase
      end
    end.compact
  end

  private_class_method def self.match_regex
    url = Settings.bugzilla_credentials.url.to_s.chomp("/")
    /\A((?<resolution>#{CLOSING_KEYWORDS.join("|")}):?)?\s*#{url}\/\/?(?:show_bug\.cgi\?id=)?(?<bug_id>\d+)\Z/i
  end
end
