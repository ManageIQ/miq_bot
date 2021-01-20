require 'travis'

class TravisBranchMonitor
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot, :retry => false

  include Sidetiq::Schedulable
  recurrence { hourly.minute_of_hour(0, 15, 30, 45) }

  include SidekiqWorkerMixin

  class << self
    private

    # For this class, sometimes the repo needs to be mapped to a specific
    # gitter room, so a hash is required.
    #
    # This override allows for doing this in the config
    #
    #   travis_branch_monitor:
    #     included_repos:
    #       ManageIQ/manageiq-ui-classic: ManageIQ/ui
    #       ManageIQ/manageiq-gems-pending: ManageIQ/core
    #       ManageIQ/manageiq:
    #       ManageIQ/miq_bot:
    #
    # Which you are allowed to leave the value empty, and the key will be used
    # where appropriate (not used in this class).
    #
    # The result from the above for this method will then be:
    #
    #   [
    #     [
    #       "ManageIQ/manageiq-ui-classic",
    #       "ManageIQ/manageiq-gems-pending",
    #       "ManageIQ/manageiq",
    #       "ManageIQ/miq_bot"
    #     ],
    #     []
    #   ]
    #
    def included_and_excluded_repos
      super # just used for error handling...

      [
        settings.included_repos.try(:to_h).try(:stringify_keys).try(:keys),
        settings.excluded_repos.try(:to_h).try(:stringify_keys).try(:keys)
      ]
    end
  end

  def perform
    if !first_unique_worker?
      logger.info("#{self.class} is already running, skipping")
    else
      process_repos
    end
  end

  def process_repos
    enabled_repos.each do |repo|
      process_repo(repo)
    end
  end

  def process_repo(repo)
    repo.regular_branch_names.each do |branch_record|
      process_branch(repo, branch_record)
    end
  end

  def process_branch(repo, branch_record)
    # If we already have a failure record, call notify with that record
    return branch_record.notify_of_failure if branch_record.previously_failing?

    # otherwise, check if any builds exist with a failures, and if so, update
    # the branch_record to add the `travis_build_failure_id`.
    v3_client     = TravisV3Client.new(:repo => Travis::Repository.find(repo.name))
    branch_builds = v3_client.repo_branch_builds(branch_record.name)

    if branch_builds.first.failed?
      first_failure = find_first_recent_failure(branch_builds)
      branch_record.update(:travis_build_failure_id => first_failure.id)

      branch_record.notify_of_failure
    end
  end

  private

  def find_first_recent_failure(builds)
    builds.take_while(&:failed?).last
  end
end
