require 'travis'
require 'gitter/api'

class BuildFailureNotifier
  def self.gitter
    @gitter ||= begin
                  api_url = Settings.gitter.api_url
                  client_settings = {
                    :token      => Settings.gitter_credentials.token,
                    :api_prefix => Settings.gitter.api_prefix,
                    :api_uri    => api_url && URI(api_url)
                  }

                  Gitter::API::Client.new(client_settings)
                end
  end

  def self.repo_room_map
    settings = Settings.travis_branch_monitor
    repo_map = settings.included_repos.to_h.merge(settings.excluded_repos.to_h)

    repo_map.stringify_keys!
    repo_map.each do |repo, room_uri|
      repo_map[repo] = repo if room_uri.nil?
    end
  end

  attr_reader :branch, :build, :repo, :repo_path, :room

  def initialize(branch)
    @branch    = branch
    @repo_path = branch.repo.name
    @repo      = Travis::Repository.find(repo_path)
    @room      = repo_room_map[repo_path]
    @build     = repo.session.find_one(Travis::Client::Build, branch.travis_build_failure_id)
  end

  def post_failure
    notification_msg = <<~MSG
      > ### :red_circle: Build Failure in #{repo_branches_markdown_url}!
      >
      > **Travis Build**:  #{travis_build_url}
    MSG
    notification_msg << "> **Failure PR**:    #{offending_pr}\n" if offending_pr
    notification_msg << "> **Commit**:        #{commit_url}\n"   if commit_url
    notification_msg << "> **Compare**:       #{compare_url}\n"  if compare_url

    gitter_room.send_message(notification_msg)
  end

  def report_passing
    notification_msg = <<~MSG
      > ### :green_heart: #{repo_branches_markdown_url} now passing!
    MSG

    gitter_room.send_message(notification_msg)
  end

  private

  def gitter
    self.class.gitter
  end

  def repo_room_map
    self.class.repo_room_map
  end

  # join room if needed, otherwise returns room
  def gitter_room
    @gitter_room ||= gitter.join_room(room)
  end

  def travis_build_url
    "https://travis-ci.org/#{repo_path}/builds/#{build.id}"
  end

  # find the PR that caused this mess...
  def offending_pr
    if build.commit && build.commit.message =~ /^Merge pull request #(\d+)/
      "https://github.com/#{repo_path}/issues/#{$1}"
    end
  end

  def commit_url
    if build.commit
      "https://github.com/#{repo_path}/commit/#{build.commit.sha[0, 8]}"
    end
  end

  def compare_url
    build.commit.compare_url if build.commit && build.commit.compare_url
  end

  def repo_branches_markdown_url
    "[`#{repo_path}`](https://travis-ci.org/#{repo_path}/branches)"
  end
end
