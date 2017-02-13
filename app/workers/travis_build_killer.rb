class TravisBuildKiller
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot, :retry => false

  include Sidetiq::Schedulable
  recurrence { hourly.minute_of_hour(0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55) }

  include SidekiqWorkerMixin

  def perform
    if !first_unique_worker?
      logger.info "#{self.class} is already running, skipping"
    else
      process_repo
    end
  end

  private

  attr_accessor :repo

  def process_repo
    @repo = Repo.where(:name => "ManageIQ/manageiq").first
    if @repo.nil?
      logger.info "The ManageIQ/manageiq repo has not been defined.  Skipping."
      return
    end

    kill_builds
  end

  def kill_builds
    repo.with_travis_service do |travis|
      pending_builds = travis.builds.take_while { |b| b.pending? || b.canceled? }.reject(&:canceled?)

      out_dated_builds = pending_builds.group_by { |b| b.pull_request_number || b.branch_info }.flat_map { |_key, builds| builds[1..-1] }
      out_dated_builds.each do |b|
        if b.pull_request?
          logger.info "Canceling Travis build ##{b.number} for PR ##{b.pull_request_number}"
          b.cancel
        elsif b.running?
          logger.info "Skipping currently running Travis build ##{b.number} for merge commit"
        else
          logger.info "Canceling Travis build ##{b.number} for merge commit"
          b.cancel
        end
      end

      long_running_jobs = pending_builds.select(&:running?).flat_map { |b| b.jobs.select { |j| j.running? && (Time.now.getlocal - j.started_at) >= 1.hour } }
      long_running_jobs.each do |b|
        logger.info "Canceling long running Travis build ##{b.number}, something must be wrong."
        b.cancel
      end
    end
  end
end
