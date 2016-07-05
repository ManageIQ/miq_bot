module CommitMonitorHandlers::Batch
  class GithubPrCommenter
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot_glacial

    include BatchJobWorkerMixin
    include BranchWorkerMixin

    def self.batch_workers
      [DiffContentChecker, DiffFilenameChecker]
    end

    def perform(batch_job_id, branch_id, _new_commits)
      return unless find_batch_job(batch_job_id)

      unless find_branch(branch_id, :pr)
        complete_batch_job
        return
      end

      process
      complete_batch_job
    end

    private

    attr_reader :github

    def tag
      "<github_pr_commenter_batch />"
    end

    def header
      "#{tag}Some comments on #{"commit".pluralize(commits.length)} #{commit_range_text}\n"
    end

    def continuation_header
      "#{tag}**...continued**\n"
    end

    def process
      logger.info("Adding batch comment to PR #{pr_number}.")

      branch.repo.with_github_service do |github|
        @github = github
        replace_batch_comments
      end
    end

    def replace_batch_comments
      github.replace_issue_comments(pr_number, new_comments) do |old_comment|
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

      message_builder = MiqToolsServices::Github::MessageBuilder.new(header, continuation_header)
      message_builder.write("")
      message_builder.write_lines(content.lines)
      message_builder.comments
    end

    def merged_results
      @merged_results ||= batch_job.entries.collect(&:result).flatten.compact
    end
  end
end
