class TravisBuildKiller
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  include MiqToolsServices::SidekiqWorkerMixin
  sidekiq_options :queue => :miq_bot, :retry => false

  recurrence { hourly.minute_of_hour(0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55) }

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
    @repo = CommitMonitorRepo.where(:upstream_user => "ManageIQ", :name => "manageiq").first
    if @repo.nil?
      logger.info "The ManageIQ/manageiq repo has not been defined.  Skipping."
      return
    end

    kill_builds
  end

  def kill_builds
    repo.with_travis_service do |travis|
      builds_to_cancel = travis.builds
        .take_while { |b| b.pending? || b.canceled? }
        .reject(&:canceled?)
        .group_by(&:pull_request_number)
        .flat_map { |_pr_number, builds| builds[1..-1] }

      builds_to_cancel.each do |b|
        for_what = b.pull_request? ? "PR ##{b.pull_request_number}" : "merge commit"
        logger.info "Canceling Travis build ##{b.number} for #{for_what}"
        b.cancel
      end
    end
  end
end
