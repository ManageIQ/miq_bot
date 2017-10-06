module CodeAnalysisMixin
  def merge_linter_results(*results)
    return if results.empty?

    new_results = results[0].dup

    results[1..-1].each do |result|
      %w(offense_count target_file_count inspected_file_count).each do |m|
        new_results['summary'][m] += result['summary'][m]
      end
      new_results['files'] += result['files']
    end

    new_results
  end

  def run_all_linters
    unmerged_results = []
    unmerged_results << Linter::Rubocop.new(branch).run
    unmerged_results << Linter::Haml.new(branch).run
    unmerged_results << Linter::Yaml.new(branch).run
    unmerged_results.compact!
  end
end
