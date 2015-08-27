module CommitMonitorHandlers
  module CommitRange
    class GemfileChecker
      include Sidekiq::Worker
      sidekiq_options :queue => :miq_bot

      include BranchWorkerMixin

      LABEL_NAME = "gem changes".freeze

      def self.handled_branch_modes
        [:pr]
      end

      attr_reader :github

      def perform(branch_id, _new_commits)
        return unless find_branch(branch_id, :pr)
        return unless verify_branch_enabled

        files = diff_details_for_branch.keys
        return unless files.any? { |f| File.basename(f) == "Gemfile" }

        process_branch
      end

      private

      def diff_details_for_branch
        branch.repo.with_git_service do |git|
          git.diff_details(*commit_range)
        end
      end

      def tag
        "<gemfile_checker />"
      end

      def gemfile_comment
        where   = "#{'commit'.pluralize(commits.length)} #{commit_range_text}"
        message = "#{tag}Gemfile changes detected in #{where}."

        contacts = Settings.gemfile_checker.pr_contacts.join(" ")
        message << " /cc #{contacts}" unless contacts.blank?

        message
      end

      def process_branch
        logger.info("Updating PR #{pr_number} with Gemfile comment.")

        branch.repo.with_github_service do |github|
          @github = github
          replace_gemfile_comments
          add_pr_label
        end
      end

      def replace_gemfile_comments
        github.replace_issue_comments(pr_number, gemfile_comment) do |old_comment|
          gemfile_comment?(old_comment)
        end
      end

      def add_pr_label
        logger.info("Updating PR #{pr_number} with label #{LABEL_NAME.inspect}")
        github.add_issue_labels(pr_number, LABEL_NAME)
      end

      def gemfile_comment?(comment)
        comment.body.start_with?(tag)
      end
    end
  end
end
