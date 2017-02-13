module CommitMonitorHandlers::Batch
  class GithubPrCommenter
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot_glacial

    include BatchJobWorkerMixin
    include BranchWorkerMixin

    def self.batch_workers
      [DiffContentChecker, DiffFilenameChecker]
    end

    def self.handled_branch_modes
      [:pr]
    end

    def perform(batch_job_id, branch_id, _new_commits)
      return unless find_batch_job(batch_job_id)
      return skip_batch_job unless find_branch(branch_id, :pr)

      replace_batch_comments
      complete_batch_job
    end

    private

    def tag
      "<github-pr-commenter-batch />"
    end

    def header
      "#{tag}Some comments on #{"commit".pluralize(commits.length)} #{commit_range_text}\n"
    end

    def continuation_header
      "#{tag}**...continued**\n"
    end

    def replace_batch_comments
      logger.info("Adding batch comment to PR #{pr_number}.")

      GithubService.replace_comments(fq_repo_name, pr_number, new_comments) do |old_comment|
        batch_comment?(old_comment)
      end
    end

    def batch_comment?(comment)
      comment.body.start_with?(tag)
    end

    def new_comments
      return [] unless merged_results.any?

      content = OffenseMessage.new
      content.entries = merged_results

      message_builder = GithubService::MessageBuilder.new(header, continuation_header)
      message_builder.write("")
      message_builder.write_lines(content.lines)
      message_builder.comments
    end

    def merged_results
      @merged_results ||= batch_job.entries.collect(&:result).flatten.compact
    end
  end
end
