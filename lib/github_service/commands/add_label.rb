module GithubService
  module Commands
    class AddLabel < Base
      private

      def _execute(issuer:, value:)
        valid, invalid = extract_label_names(value)

        if invalid.any?
          message = "@#{issuer} Cannot apply the following label#{"s" if invalid.length > 1} because they are not recognized: "
          message << invalid.join(", ")
          issue.add_comment(message)
        end

        if valid.any?
          valid.reject! { |l| issue.applied_label?(l) }
          issue.add_labels(valid)
        end
      end

      def extract_label_names(value)
        label_names = value.split(",").map { |label| label.strip.downcase }
        validate_labels(label_names)
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
