require 'travis/client'

module TravisEventHandlers
  class StalledFinishedJob
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot

    STALLED_BUILD_TEXT = "\n\nNo output has been received in the last 10 minutes, this potentially indicates a stalled build or something wrong with the build itself.\n\nThe build has been terminated\n\n"
    HANDLED_EVENTS  = ['job:finished'].freeze
    ERROR = "errored".freeze
    COMMENT_TAG = "<stalled_finished_job />".freeze

    attr_reader :repo, :slug, :number, :event_type, :state

    def perform(slug, number, event_type, state, branch_or_pr_number, pull_request)
      @slug       = slug
      @number     = number
      @event_type = event_type
      @state      = state

      return if skip_event? || skip_state?

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
      travis_repo = Travis::Repository.find(slug) or return
      job = find_job(travis_repo, number) or return
      return unless job_stalled?(job)

      message = "Detected and restarted stalled travis job."
      branch.write_github_comment(COMMENT_TAG + message)
      logger.info("#{self.class.name}##{__method__} #{message}")

      # Must have github token in password field
      Travis.github_auth(Settings.github_credentials.password)
      job.restart
    end

    protected

    #### Incoming argument checks
    def skip_event?
      !HANDLED_EVENTS.include?(event_type).tap do |skipped|
        if skipped
          logger.debug("#{self.class.name}##{__method__} [#{slug}##{number}] Skipping #{event_type}")
        end
      end
    end

    def skip_state?
      state != ERROR.tap do |skipped|
        if skipped
          logger.debug("#{self.class.name}##{__method__} [#{slug}##{number}] Skipping state: #{state}")
        end
      end
    end

    ### Travis checks
    def find_job(repo, number)
      job =
        begin
          repo.job(number)
        rescue => err
          logger.warn("#{self.class.name}##{__method__} [#{slug}##{number}] can't find job #{number}, #{err}")
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
