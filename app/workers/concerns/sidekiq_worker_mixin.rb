require "active_support/core_ext/module/delegation"
require "active_support/concern"

module SidekiqWorkerMixin
  extend ActiveSupport::Concern

  included do
    delegate :settings, :enabled_repos, :enabled_repo_names, :enabled_for?, :to => :class
    delegate :sidekiq_queue, :workers, :running?, :to => :class
  end

  module ClassMethods
    #
    # Settings helper methods
    #

    def settings_key
      @settings_key ||= name.split("::").last.underscore
    end
    private :settings_key

    def settings
      Settings[settings_key] || Config::Options.new
    end

    def included_and_excluded_repos
      i = settings.included_repos.try(:flatten)
      e = settings.excluded_repos.try(:flatten)
      raise "Do not specify both excluded_repos and included_repos in settings for #{settings_key.inspect}" if i && e
      return i, e
    end
    private :included_and_excluded_repos

    def enabled_repos
      i, e = included_and_excluded_repos

      if i && !e
        Repo.where(:name => i)
      elsif !i && e
        Repo.where.not(:name => e)
      elsif !i && !e
        Repo.all
      end
    end

    def enabled_repo_names
      enabled_repos.collect(&:name)
    end

    def enabled_for?(repo)
      i, e = included_and_excluded_repos

      if i && !e
        i.include?(repo.name)
      elsif !i && e
        !e.include?(repo.name)
      elsif !i && !e
        true
      end
    end

    #
    # Sidekiq Helper methods
    #

    def sidekiq_queue
      sidekiq_options unless get_sidekiq_options # init the sidekiq_options_hash
      sidekiq_options_hash["queue"]
    end

    def workers
      queue = sidekiq_queue.to_s

      workers = Sidekiq::WorkSet.new
      workers = workers.select do |_processid, _threadid, work|
        work.job.queue == queue && work.job.klass == name
      end
      workers.sort_by! { |_processid, _threadid, work| work.job.enqueued_at }

      workers
    end

    def running?(workers = nil)
      (workers || self.workers).any?
    end
  end

  #
  # Sidekiq Helper methods
  #

  def first_unique_worker?(workers = nil)
    _processid, _threadid, work = (workers || self.workers).first
    work.nil? || work.job.jid == jid
  end
end
