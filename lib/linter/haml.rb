module Linter
  class Haml < Base
    private

    def config_files
      [".haml-lint.yml"] + Linter::Rubocop::CONFIG_FILES
    end

    def linter_executable
      'haml-lint *'
    end

    def linter_env
      parser_stub_path = Rails.root.join("vendor", "stubs").to_s
      {"RUBYOPT" => "-I #{parser_stub_path}"}
    end

    def options
      {:reporter => 'json'}
    end

    def filtered_files(files)
      files.select { |file| file.end_with?(".haml") }
    end
  end
end
