def rubocop_results
  # To regenerate the results.json files, just delete them
  unless File.exist?(rubocop_json_file)
    rubocop = JSON.parse(`rubocop --format=json #{rubocop_check_path}`)
    hamllint = JSON.parse(`haml-lint -i RuboCop --reporter=json #{rubocop_check_path}`)

    %w(offense_count target_file_count inspected_file_count).each do |m|
      rubocop['summary'][m] += hamllint['summary'][m]
    end
    rubocop['files'] += hamllint['files']
    File.write(rubocop_json_file, rubocop.to_json)
  end
  JSON.parse(File.read(rubocop_json_file))
end

def rubocop_json_file
  rubocop_check_path.join("results.json")
end

def rubocop_check_path
  Pathname.new(example.file_path).expand_path.dirname.join("data", rubocop_check_directory)
end

def rubocop_check_path_file(file)
  rubocop_check_path.join(file).relative_path_from(Rails.root)
end

def rubocop_check_directory
  example.description.gsub(" ", "_")
end

def rubocop_version
  RuboCop::Version.version
end
