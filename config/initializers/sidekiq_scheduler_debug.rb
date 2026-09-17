module SidekiqScheduler
  module Utils
    class << self
      alias_method :new_rufus_scheduler_without_debug, :new_rufus_scheduler

      def new_rufus_scheduler(options = {})
        new_rufus_scheduler_without_debug(options).tap do |scheduler|
          scheduler.define_singleton_method(:on_post_trigger) do |job, triggered_time|
            job_name = job.tags[0]
            return unless job_name

            Sidekiq.logger.debug("[SidekiqScheduler debug] on_post_trigger fired for #{job_name} at #{triggered_time}")

            begin
              SidekiqScheduler::Utils.update_job_last_time(job_name, triggered_time)
            rescue => e
              Sidekiq.logger.error("[SidekiqScheduler debug] update_job_last_time failed for #{job_name}: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
              raise
            end

            begin
              SidekiqScheduler::Utils.update_job_next_time(job_name, job.next_time)
            rescue => e
              Sidekiq.logger.error("[SidekiqScheduler debug] update_job_next_time failed for #{job_name}: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
              raise
            end

            Sidekiq.logger.debug("[SidekiqScheduler debug] on_post_trigger completed for #{job_name}")
          end
        end
      end
    end
  end
end
