def rubocop_results
  # To regenerate the results.json files, just delete them
  File.write(rubocop_json_file, `rubocop --format=json #{rubocop_check_path}`) unless File.exist?(rubocop_json_file)
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
