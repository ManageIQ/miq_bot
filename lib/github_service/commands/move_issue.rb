module GithubService
  module Commands
    class MoveIssue < Base
      restrict_to :organization

      private

      def _execute(issuer:, value:, **_)
        @dest_organization_name, @dest_repo_name = value.split("/", 2).unshift(issue.organization_name).last(2)
        @dest_fq_repo_name = "#{@dest_organization_name}/#{@dest_repo_name}"

        validate

        if errors.present?
          issue.add_comment("@#{issuer} :x: `move_issue` failed. #{errors.to_sentence.capitalize}.")
        else
          new_issue = GithubService.create_issue(@dest_fq_repo_name, issue.title, new_issue_body)
          issue.add_comment("This issue has been moved to #{new_issue.html_url}")
          GithubService.close_issue(issue.fq_repo_name, issue.number)
        end
      end

      def errors
        @errors ||= []
      end

      def validate
        if issue.repo_name.downcase == @dest_repo_name.downcase
          errors << "issue already exists on the '#{issue.repo_name}' repository"
        end
        if issue.pull_request?
          errors << "a pull request cannot be moved"
        end
        if issue.organization_name.downcase != @dest_organization_name.downcase
          errors << "cannot move issue to repository outside of the #{issue.organization_name} organization"
        end
        unless GithubService.repository?(@dest_fq_repo_name)
          errors << "repository does not exist or is unreachable"
        end
      end

      def new_issue_body
        <<-EOS
#{issue.body}

---

*This issue was moved to this repository from #{issue.html_url}, originally opened by @#{issue.author}*
        EOS
      end
    end
  end
end
