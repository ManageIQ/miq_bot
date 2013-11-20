#!/usr/bin/env ruby

require_relative 'logging'
require 'yaml'
require 'minigit'

# Watches git branches for new commits, and on each new commit, triggers a callback.
class CommitMonitor
  include Logging

  REPOSITORY_BASE = File.expand_path("~/dev")
  COMMIT_MONITOR_YAML_FILE  = File.join(File.dirname(__FILE__), 'commit_monitor.yml')
  COMMIT_MONITOR_LOG_FILE   = File.join(File.dirname(__FILE__), 'commit_monitor.log')

  def initialize
    load_yaml_file
  end

  def process_new_commits
    @repos.each do |repo_name, branches|
      git = MiniGit::Capturing.new(File.join(REPOSITORY_BASE, repo_name))

      branches.each do |branch, last_commit|
        git.checkout branch
        git.pull

        commits = find_new_commits(git, last_commit)
        commits.each do |commit|
          process_commit(git, commit)
        end

        @repos[repo_name][branch] = commits.last || last_commit
        dump_yaml_file
      end
    end
  end

  private

  def find_new_commits(git, last_commit)
    git.rev_list({:reverse => true}, "#{last_commit}..HEAD").chomp.split("\n")
  end

  def process_commit(git, commit)
    message = git.log("-1", commit)
    message.each_line do |line|
      if line =~ %r{^\s*https://bugzilla\.redhat\.com/show_bug\.cgi\?id=(\d+)$}
        logger.info("Updating bug id #{$1} in Bugzilla.")
      end
    end
  end

  def load_yaml_file
    @repos = YAML.load_file(COMMIT_MONITOR_YAML_FILE)
  end

  def dump_yaml_file
    File.open(COMMIT_MONITOR_YAML_FILE, 'w+') do |f|
      f.write(YAML.dump(@repos))
    end
  end
end

if $0 == __FILE__
  MiniGit.debug = true
  Logging.logger = Logger.new(STDOUT)

  bot = CommitMonitor.new
  loop do
    bot.process_new_commits
    sleep(5)
  end
end

