require 'yaml'
require 'minigit'

class CommitMonitorWorker
  include Sidekiq::Worker

  def initialize(*args)
    MiniGit.debug = true
    super
  end

  def perform
    load_configuration

    @repos.each do |repo, branches|
      MiniGitMutex.synchronize do
        git = MiniGit::Capturing.new(File.join(@repo_base, repo))

        branches.each do |branch, options|
          last_commit = options["last_commit"]

          git.checkout branch
          git.pull

          commits = find_new_commits(git, last_commit)
          commits.each do |commit|
            process_commit(repo, branch, commit)
          end

          @repos[repo][branch]["last_commit"] = commits.last || last_commit
          dump_configuration
        end
      end
    end
  end

  private

  COMMIT_MONITOR_REPOS_YAML = Rails.root.join('config/commit_monitor_repos.yml')
  COMMIT_MONITOR_YAML       = Rails.root.join('config/commit_monitor.yml')

  def find_new_commits(git, last_commit)
    git.rev_list({:reverse => true}, "#{last_commit}..HEAD").chomp.split("\n")
  end

  def process_commit(repo, branch, commit)
    handlers.each do |h|
      h.perform_async(repo, branch, commit)
    end
  end

  def handlers
    Dir.glob(Rails.root.join("app/workers/commit_monitor_handlers/*.rb")).collect do |f|
      klass = File.basename(f, ".rb").classify
      CommitMonitorHandlers.const_get(klass)
    end
  end

  def load_configuration
    @repos   = YAML.load_file(COMMIT_MONITOR_REPOS_YAML)
    @options = YAML.load_file(COMMIT_MONITOR_YAML)

    @repo_base = File.expand_path(@options["repository_base"])
  end

  def dump_configuration
    File.write(COMMIT_MONITOR_REPOS_YAML, YAML.dump(@repos))
  end
end
