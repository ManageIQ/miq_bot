class CommitMonitorHandlers::GithubPrCommenter::DiffFilenameChecker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot_glacial

  include BatchEntryWorkerMixin
  include BranchWorkerMixin

  def perform(batch_entry_id, branch_id, _new_commits)
    return unless find_batch_entry(batch_entry_id)
    return skip_batch_entry unless find_branch(branch_id, :pr)

    complete_batch_entry(:result => process_files)
  end

  private

  def process_files
    @offenses = []

    check_diff_files

    @offenses
  end

  def check_diff_files
    branch.git_service.diff.new_files.each do |file|
      validate_migration_timestamp(file)
    end
  rescue GitService::UnmergeableError
    nil # Avoid working on unmergeable PRs
  end

  def validate_migration_timestamp(file)
    return unless file.include?("db/migrate/")
    ts = File.basename(file).split("_").first
    return if valid_timestamp?(ts)

    @offenses << OffenseMessage::Entry.new(:error, "Bad Migration Timestamp", file)
  end

  def valid_timestamp?(ts)
    Time.parse(ts)
  rescue ArgumentError
    false
  end
end
