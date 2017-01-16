class PivotalService
  include ServiceMixin

  # https://www.pivotaltracker.com/story/show/<story_id>
  # https://pivotaltracker.com/story/show/<story_id>
  # https://www.pivotaltracker.com/n/projects/<project_id>/stories/<story_id>
  # https://pivotaltracker.com/n/projects/<project_id>/stories/<story_id>
  URL_REGEX = %r{https://(?:www\.)?pivotaltracker\.com/(?:story/show/(?<id>\d+)|n/projects/\d+/stories/(?<id>\d+))}

  def initialize
    service # initialize the service
  end

  def service
    @service ||= begin
      require 'tracker_api'
      TrackerApi::Client.new(credentials.to_h.symbolize_keys)
    end
  end

  def self.ids_in_git_commit_message(message)
    ids = []
    message.each_line.collect do |line|
      match = URL_REGEX.match(line)
      ids << match[:id].to_i if match
    end
    ids.uniq
  end
end
