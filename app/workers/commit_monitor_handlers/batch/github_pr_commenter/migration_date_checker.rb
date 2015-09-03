require 'time'

module CommitMonitorHandlers::Batch
  class GithubPrCommenter::MigrationDateChecker
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot

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
        diff_files_for_commit_range.select do |f|
          next unless f.include?("db/migrate/")
          valid_timestamp?(File.basename(f).split("_").first)
        end
    end

    def valid_timestamp?(ts)
      Time.parse(ts)
    rescue ArgumentError
      false
    end

    def diff_files_for_commit_range
      branch.repo.with_git_service do |git|
        git.diff_details(*commit_range).keys
      end
    end
  end
end
