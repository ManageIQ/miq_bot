module GithubService
  module Commands
    class RemoveLabel < Base
      include IsTeamMember

      alias_as 'rm_label'

      private

      def _execute(issuer:, value:)
        unremovable    = []
        valid, invalid = extract_label_names(value)
        process_extracted_labels(issuer, valid, invalid, unremovable)

        if invalid.any?
          message = "@#{issuer} Cannot remove the following label#{"s" if invalid.length > 1} because they are not recognized: "
          message << invalid.join(", ")
          issue.add_comment(message)
        end

        if unremovable.any?
          labels       = "label#{"s" if unremovable.length > 1}"
          triage_perms = "[triage team permissions](https://github.com/orgs/ManageIQ/teams/core-triage)"
          message      = "@#{issuer} Cannot remove the following #{labels} since they require #{triage_perms}: "
          message << unremovable.join(", ")
          issue.add_comment(message)
        end

        valid.each do |l|
          issue.remove_label(l) if issue.applied_label?(l)
        end
      end

      def extract_label_names(value)
        label_names = value.split(",").map { |label| label.strip.downcase }
        validate_labels(label_names)
      end

      def process_extracted_labels(issuer, valid_labels, _invalid_labels, unremovable)
        unless triage_member?(issuer)
          valid_labels.each { |label| unremovable << label if Settings.labels.unremovable.include?(label) }
          unremovable.each  { |label| valid_labels.delete(label) }
        end
      end

      def validate_labels(label_names)
        # First reload the cache if there are any invalid labels
        GithubService.refresh_labels(issue.fq_repo_name) unless label_names.all? { |l| GithubService.valid_label?(issue.fq_repo_name, l) }

        # Then see if any are *still* invalid and split the list
        label_names.partition { |l| GithubService.valid_label?(issue.fq_repo_name, l) }
      end
    end
  end
end
