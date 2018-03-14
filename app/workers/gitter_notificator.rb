require 'gitter'
require 'travis'

class GitterNotificator
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot_glacial, :retry => false

  include Sidetiq::Schedulable
  recurrence { minutely(10) }

  include SidekiqWorkerMixin

  def perform
    init
  end

  private

  def init
    gitter_token = Settings.travis_monitor.gitter_token

    Settings.travis_monitor.branches.each do |element|
      build_states = latest_builds(element.repo, element.branch)
      msg = check(build_states, element.repo, element.branch)
      gitter_send(element.gitter_room, msg, gitter_token) unless msg.nil?
    end
  end

  def check(builds, repository, branch)
    msg = nil

    if builds[0] == 'passed' && builds[1] == 'failed'
      msg = ":sos: :warning: \"#{branch}\" in \"#{repository}\" is broken :bangbang: :boom:"
    elsif builds[0] == 'failed' && builds[1] == 'passed'
      msg = ":white_check_mark: Broken branch has been fixed :green_heart:"
    end

    msg
  end

  def latest_builds(repository, branch)
    repo = Travis::Repository.find(repository)
    repo.builds.lazy.select { |b| b.branch_info == branch }.take(2).map(&:state).to_a
  end

  def gitter_send(room_name, message, gitter_token)
    client = Gitter::Client.new(gitter_token)
    room_id = client.rooms.find { |room| room.name == room_name }.id
    client.send_message(message, room_id)
  end
end
