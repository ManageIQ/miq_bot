module CommitMonitorHandlers::Batch
  class GithubPrCommenter
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot

    include BatchJobWorkerMixin
    include BranchWorkerMixin

    def self.batch_workers
      [GemfileChecker, MigrationDateChecker]
    end

    def self.handled_branch_modes
      [:pr]
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
      return [] unless entries_with_results.any?

      message_builder = MiqToolsServices::Github::MessageBuilder.new(header, continuation_header)
      entries_with_results.each do |entry|
        message_builder.write("* #{entry.result}")
      end
      message_builder.comments
    end

    def entries_with_results
      @entries_with_results ||= batch_job.entries.select(&:result)
    end
  end
end
