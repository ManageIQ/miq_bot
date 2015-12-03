require 'time'

module CommitMonitorHandlers::Batch
  class GithubPrCommenter::MigrationDateChecker
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot_glacial

    include BatchEntryWorkerMixin
    include BranchWorkerMixin

    def perform(batch_entry_id, branch_id, _new_commits)
      return unless find_batch_entry(batch_entry_id)
      return unless find_branch(branch_id, :pr)

      complete_batch_entry(bad_migrations.any? ? {:result => new_comment} : {})
    end

    private

    def new_comment
      ":red_circle: Bad migration #{"date".pluralize(bad_migrations.length)}: #{bad_migrations.join(", ")}"
    end

    def bad_migrations
      @bad_migrations ||=
        migration_files.reject do |f|
          ts = File.basename(f).split("_").first
          valid_timestamp?(ts)
        end
    end

    def valid_timestamp?(ts)
      Time.parse(ts)
    rescue ArgumentError
      false
    end

    def migration_files
      diff_file_names_for_merge.select do |f|
        f.include?("db/migrate/")
      end
    end
  end
end
