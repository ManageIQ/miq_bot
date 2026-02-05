module CodeAnalysisMixin
  def merged_linter_results
    results = {
      "files"   => [],
      "summary" => {
        "inspected_file_count" => 0,
        "offense_count"        => 0,
        "target_file_count"    => 0,
      },
    }

    run_all_linters.each do |result|
      %w[offense_count target_file_count inspected_file_count].each do |m|
        results['summary'][m] += result['summary'][m]
      end
      results['files'] += result['files']
    end

    results
  end

  def run_all_linters
    unmerged_results = []
    unmerged_results << Linter::Rubocop.new(branch).run
    unmerged_results << Linter::Haml.new(branch).run
    unmerged_results << Linter::Yaml.new(branch).run
    unmerged_results.tap(&:compact!)
  end
end
