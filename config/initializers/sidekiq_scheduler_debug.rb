module SidekiqScheduler
  module Utils
    class << self
      alias_method :new_rufus_scheduler_without_debug, :new_rufus_scheduler

      def new_rufus_scheduler(options = {})
        new_rufus_scheduler_without_debug(options).tap do |scheduler|
          scheduler.define_singleton_method(:on_post_trigger) do |job, triggered_time|
            job_name = job.tags[0]
            return unless job_name

            Sidekiq.logger.info("[SidekiqScheduler debug] on_post_trigger fired for #{job_name} at #{triggered_time}, job.next_time=#{job.next_time}")

            begin
              SidekiqScheduler::Utils.update_job_last_time(job_name, triggered_time)
            rescue Exception => e # rubocop:disable Lint/RescueException
              Sidekiq.logger.error("[SidekiqScheduler debug] update_job_last_time failed for #{job_name}: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
              raise
            end

            begin
              SidekiqScheduler::Utils.update_job_next_time(job_name, job.next_time)
            rescue Exception => e # rubocop:disable Lint/RescueException
              Sidekiq.logger.error("[SidekiqScheduler debug] update_job_next_time failed for #{job_name}: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
              raise
            end

            Sidekiq.logger.info("[SidekiqScheduler debug] on_post_trigger completed for #{job_name}, job.next_time=#{job.next_time}")
          end

          scheduler.define_singleton_method(:on_error) do |job, err|
            Sidekiq.logger.error(
              "[SidekiqScheduler debug] rufus scheduler thread on_error: " \
              "#{err.class}: #{err.message}\n#{err.backtrace.join("\n")}"
            )
            super(job, err)
          end

          Thread.new do
            scheduler.thread.report_on_exception = true
            scheduler.thread.join rescue nil
            Sidekiq.logger.error(
              "[SidekiqScheduler debug] rufus scheduler thread exited: " \
              "alive=#{scheduler.thread.alive?} status=#{scheduler.thread.status.inspect}"
            )
          end

          Thread.new do
            loop do
              sleep 60
              thread = scheduler.thread
              Sidekiq.logger.info(
                "[SidekiqScheduler debug] rufus scheduler thread: alive=#{thread&.alive?} " \
                "status=#{thread&.status.inspect} jobs=#{scheduler.jobs.size} " \
                "next_times=#{scheduler.jobs.map { |j| [j.tags.first, j.next_time] }.to_h}"
              )
            end
          end
        end
      end
    end
  end
end
