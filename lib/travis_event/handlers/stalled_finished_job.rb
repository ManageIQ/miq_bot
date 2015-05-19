require 'travis/client'

module TravisEvent
  module Handlers
    class StalledFinishedJob
      include Sidekiq::Worker
      sidekiq_options :queue => :miq_bot

      STALLED_BUILD_TEXT = "\n\nNo output has been received in the last 10 minutes, this potentially indicates a stalled build or something wrong with the build itself.\n\nThe build has been terminated\n\n"
      HANDLED_EVENTS  = ['job:finished'].freeze
      ERROR = "errored".freeze

      attr_reader :repo, :repo_name, :number, :event_type, :state

      def perform(repo_name, number, event_type, state, raw_branch_name, pull_request)
        @repo_name    = repo_name
        @number       = number
        @event_type   = event_type
        @state        = state
        @pull_request = pull_request

        return if skip_event? || skip_state?

        # Local checks: skip unknown repos or non-current branches
        branch = commit_monitor_branch(raw_branch_name) or return

        # Remote checks: Skip missing travis repo or job and non-stalled builds
        travis_repo = Travis::Repository.find(repo_name) or return
        job = find_job(travis_repo, number) or return
        return unless job_stalled?(job)

        message = "Restarting stalled job: [#{repo_name}##{number}]"
        branch.write_github_comment(message)
        logger.info("#{self.class.name}##{__method__} #{message}")
        job.restart
      end

      protected

      #### Incoming argument checks
      def skip_event?
        !HANDLED_EVENTS.include?(event_type).tap do |skipped|
          if skipped
            logger.debug("#{self.class.name}##{__method__} [#{repo_name}##{number}] Skipping #{event_type}")
          end
        end
      end

      def skip_state?
        state != ERROR.tap do |skipped|
          if skipped
            logger.debug("#{self.class.name}##{__method__} [#{repo_name}##{number}] Skipping state: #{state}")
          end
        end
      end

      ### CommitMonitorRepo and CommitMonitorBranch lookups
      def pull_request?
        @pull_request
      end

      def commit_monitor_repo
        user, name = repo_name.split("/")
        CommitMonitorRepo.where(:upstream_user => user, :name => name).first.tap do |repo|
          unless repo
            logger.warn("#{self.class.name}##{__method__} [#{repo_name}##{number}] Can't find CommitMonitorRepo with user: #{user}, name: #{name}")
          end
        end
      end

      def build_branch_name(raw_branch_name)
        pull_request? ? "pr/#{raw_branch_name}" : raw_branch_name
      end

      def commit_monitor_branch(raw_branch_name)
        repo = commit_monitor_repo
        return unless repo

        branch_name = build_branch_name(raw_branch_name)
        repo.branches.where(:name => branch_name).first.tap do |branch|
          unless branch
            logger.warn("#{self.class.name}##{__method__} [#{repo_name}##{number}] Can't find CommitMonitorBranch with name: #{branch_name}")
          end
        end
      end

      ### Travis checks
      def find_job(repo, number)
        job =
          begin
            repo.job(number)
          rescue
            logger.warn("#{self.class.name}##{__method__} [#{repo_name}##{number}] can't find job #{number}, #{$!}")
            nil
          end

        raise "Job cannot be found, will retry later" if job.nil?
        job
      end

      def job_stalled?(job)
        job.log.clean_body.end_with?(STALLED_BUILD_TEXT).tap do |stalled|
          unless stalled
            logger.debug("#{self.class.name}##{__method__} [#{job.inspect_info}] Skipping non-stalled job")
          end
        end
      end
    end
  end
end
