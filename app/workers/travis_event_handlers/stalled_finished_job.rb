require 'travis/client'

module TravisEventHandlers
  class StalledFinishedJob
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot

    STALLED_BUILD_TEXT = "\n\nNo output has been received in the last 10 minutes, this potentially indicates a stalled build or something wrong with the build itself.\n\nThe build has been terminated\n\n"
    HANDLED_EVENTS  = ['job:finished'].freeze
    COMMENT_TAG = "<stalled_finished_job />".freeze

    attr_reader :repo, :branch, :job, :slug, :number, :event_type, :state

    def perform(event_hash)
      @slug       = event_hash.fetch_path("payload", "repository_slug")
      @number     = event_hash.fetch_path("payload", "number")
      @event_type = event_hash.fetch_path("type")
      @state      = event_hash.fetch_path("payload", "state")
      pr_number   = event_hash.fetch_path("build", "pull_request_number")

      if skip_event?
        logger.info("#{__method__} [#{slug}##{number}] Skipping #{event_type}")
        return
      end

      if skip_state?
        logger.info("#{__method__} [#{slug}##{number}] Skipping state: #{state}")
        return
      end

      @repo = CommitMonitorRepo.with_slug(slug).first
      if @repo.nil?
        logger.warn("#{__method__} [#{slug}##{number}] Can't find CommitMonitorRepo.")
        return
      end

      @branch = @repo.branches.with_branch_or_pr_number(pr_number).first
      if @branch.nil?
        logger.warn("#{__method__} [#{slug}##{number}] Can't find CommitMonitorBranch with name: #{branch_or_pr_number}")
        return
      end

      # Remote checks: Skip missing travis repo or job and non-stalled builds
      @repo.with_travis_service do |travis_repo|
        @job = find_job(travis_repo, number)
        if @job.nil?
          logger.warn("#{__method__} [#{slug}##{number}] Can't find Travis::Job.")
          return
        end

        unless job_stalled?
          logger.info("#{__method__} [#{@job.inspect_info}] Skipping non-stalled job")
          return
        end

        restart_job
      end
    end

    protected

    #### Incoming argument checks
    def skip_event?
      !HANDLED_EVENTS.include?(event_type)
    end

    def skip_state?
      state != "errored"
    end

    ### Travis checks
    def find_job(travis_repo, number)
      travis_repo.job(number)
    rescue
      nil
    end

    def job_stalled?
      job.log.clean_body.end_with?(STALLED_BUILD_TEXT)
    end

    def restart_job
      logger.info("#{__method__} [#{job.inspect_info}] Attempting to restart job...")

      begin
        job.restart
      rescue => err
        logger.error("#{__method__} [#{job.inspect_info}] Failed to restart job with error: #{err}")
        branch.write_github_comment("#{COMMENT_TAG}Detected stalled travis job, but failed to restart due to error:\n\n```\n#{err}\n```")
      else
        branch.write_github_comment("#{COMMENT_TAG}Detected and restarted stalled travis job.")
      end
    end
  end
end
