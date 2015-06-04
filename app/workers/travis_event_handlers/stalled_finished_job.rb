require 'travis/client'

module TravisEventHandlers
  class StalledFinishedJob
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot

    STALLED_BUILD_TEXT = "\n\nNo output has been received in the last 10 minutes, this potentially indicates a stalled build or something wrong with the build itself.\n\nThe build has been terminated\n\n"
    HANDLED_EVENTS  = ['job:finished'].freeze
    COMMENT_TAG = "<stalled_finished_job />".freeze

    attr_reader :repo, :slug, :number, :event_type, :state

    def perform(slug, number, event_type, state, branch_or_pr_number)
      @slug       = slug
      @number     = number
      @event_type = event_type
      @state      = state

      if skip_event?
        logger.info("#{self.class.name}##{__method__} [#{slug}##{number}] Skipping #{event_type}")
        return
      end

      if skip_state?
        logger.info("#{self.class.name}##{__method__} [#{slug}##{number}] Skipping state: #{state}")
        return
      end

      repo = CommitMonitorRepo.with_slug(slug).first
      if repo.nil?
        logger.warn("#{self.class.name}##{__method__} [#{slug}##{number}] Can't find CommitMonitorRepo with user: #{user}, name: #{name}")
        return
      end

      branch = repo.branches.with_branch_or_pr_number(branch_or_pr_number).first
      if branch.nil?
        logger.warn("#{self.class.name}##{__method__} [#{slug}##{number}] Can't find CommitMonitorBranch with name: #{branch_name}")
        return
      end

      # Remote checks: Skip missing travis repo or job and non-stalled builds
      repo.with_travis_service do |travis_repo|
        job = find_job(travis_repo, number)
        if job.nil?
          logger.warn("#{self.class.name}##{__method__} [#{slug}##{number}] Can't find Travis::Job.")
          return
        end

        unless job_stalled?(job)
          logger.info("#{self.class.name}##{__method__} [#{job.inspect_info}] Skipping non-stalled job")
          return
        end
      end

      message = "Detected and restarted stalled travis job."
      branch.write_github_comment(COMMENT_TAG + message)
      logger.info("#{self.class.name}##{__method__} #{message}")

      job.restart
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

    def job_stalled?(job)
      job.log.clean_body.end_with?(STALLED_BUILD_TEXT)
    end
  end
end
