module GithubService
  module Commands
    class AddLabel < Base
      private

      def _execute(issuer:, value:)
        valid, invalid = extract_label_names(value)
        process_extracted_labels(valid, invalid)

        if invalid.any?
          issue.add_comment(invalid_label_message(issuer, invalid))
        end

        if valid.any?
          valid.reject! { |l| issue.applied_label?(l) }
          issue.add_labels(valid) if valid.any?
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

      def process_extracted_labels(valid_labels, invalid_labels)
        labels = GithubService.labels(issue.fq_repo_name)
        invalid_labels.reject! do |label|
          corrections = DidYouMean::SpellChecker.new(:dictionary => labels).correct(label)

          if corrections.count == 1
            valid_labels << corrections.first
          end
        end

        [valid_labels, invalid_labels]
      end

      def invalid_label_message(issuer, invalid_labels)
        message  = "@#{issuer} "
        message << "Cannot apply the following label"
        message << "s" if invalid_labels.length > 1
        message << " because they are not recognized:\n"

        labels = GithubService.labels(issue.fq_repo_name)
        invalid_labels.each do |bad_label|
          corrections   = DidYouMean::SpellChecker.new(:dictionary => labels).correct(bad_label)
          possibilities = corrections.map { |l| "`#{l}`" }.join(", ")

          message << "* `#{bad_label}` "
          message << "(Did you mean? #{possibilities})" if corrections.any?
          message << "\n"
        end
        message << "\nAll labels for `#{issue.fq_repo_name}`:  https://github.com/#{issue.fq_repo_name}/labels"
      end
    end
  end
end

# Travis HACK v2 (debugging)
#
#

puts
puts
pp ENV
puts
puts
pp RbConfig::CONFIG
puts
puts
pp $LOAD_PATH
puts
puts

String.methosd
