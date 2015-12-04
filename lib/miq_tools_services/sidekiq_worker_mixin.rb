require "active_support/core_ext/module/delegation"
require "active_support/concern"

module MiqToolsServices
  module SidekiqWorkerMixin
    extend ActiveSupport::Concern

    included do
      delegate :sidekiq_queue, :workers, :running?, :to => self
    end

    module ClassMethods
      def sidekiq_queue
        sidekiq_options unless sidekiq_options_hash? # init the sidekiq_options_hash
        sidekiq_options_hash["queue"]
      end

      def workers
        queue = sidekiq_queue.to_s

        workers = Sidekiq::Workers.new
        workers = workers.select do |_processid, _threadid, work|
          work["queue"] == queue && work.fetch_path("payload", "class") == name
        end
        workers.sort_by! { |_processid, _threadid, work| work.fetch_path("payload", "enqueued_at") }

        workers
      end

      def running?(workers = nil)
        (workers || self.workers).any?
      end
    end

    def first_unique_worker?(workers = nil)
      _processid, _threadid, work = (workers || self.workers).first
      work.nil? || work.fetch_path("payload", "jid") == jid
    end
  end
end
