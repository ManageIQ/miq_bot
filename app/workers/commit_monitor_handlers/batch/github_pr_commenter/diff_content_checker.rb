require 'rugged'

module CommitMonitorHandlers::Batch
  class GithubPrCommenter::DiffContentChecker
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot

    include BatchEntryWorkerMixin
    include BranchWorkerMixin

    def perform(batch_entry_id, branch_id, _new_commits)
      return unless find_batch_entry(batch_entry_id)
      return unless find_branch(branch_id, :pr)
      complete_batch_entry({:result => process_lines})
    end

    private

    def process_lines
      @offenses = []

      check_diff_lines

      @offenses
    end

    def check_diff_lines
      branch.git_service.diff.with_each_line do |line, _parent_hunk, parent_patch|
        next unless line.addition?
        check_line(line, parent_patch)
      end
    rescue Rugged::IndexError # Don't put any effort into unmergeable PRS
    end

    def check_line(line, patch)
      file_path = patch.delta.new_file[:path]
      Settings.diff_content_checker.each do |offender, options|
        next if options.except.try(:any?) { |except| file_path.start_with?(except) }

        regexp = options.type == :regexp ? Regexp.new(offender.to_s) : /\b#{Regexp.escape(offender.to_s)}\b/i
        add_offense(offender, options, file_path, line) if regexp.match(line.content)
      end
    end

    def add_offense(offender, options, file_path, line)
      line_number = line.new_lineno
      message     = options.message || "Detected `#{offender}`"

      @offenses << OffenseMessage::Entry.new(options.severity, message, file_path, line_number)
    end
  end
end
