def rubocop_results
  # To regenerate the results.json files, just delete them
  unless File.exist?(rubocop_json_file)
    rubocop = JSON.parse(`rubocop --format=json --no-display-cop-names #{rubocop_check_path}`)
    hamllint = JSON.parse(`haml-lint --reporter=json #{rubocop_check_path}`)

    %w(offense_count target_file_count).each do |m|
      rubocop['summary'][m] += hamllint['summary'][m]
    end
    rubocop['files'] += hamllint['files']
    File.write(rubocop_json_file, JSON.pretty_generate(rubocop))
  end
  JSON.parse(File.read(rubocop_json_file))
end

def rubocop_json_file
  rubocop_check_path.join("results.json")
end

def rubocop_check_path
  Pathname.new(@example.file_path).expand_path.dirname.join("data", rubocop_check_directory).relative_path_from(Rails.root)
end

def rubocop_check_path_file(file)
  rubocop_check_path.join(file)
end

def rubocop_check_directory
  @example.description.gsub(" ", "_")
end

def rubocop_version
  RuboCop::Version.version
end

def hamllint_version
  HamlLint::VERSION
end

def yamllint_version
  _out, err, _ps = Open3.capture3("yamllint -v")
  err.split.last
end
