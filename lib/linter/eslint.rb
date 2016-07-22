module Linter
  class ESLint < Base
    private

    def config_files
      [".eslintrc.js", ".eslintrc.json"]
    end

    def linter_executable
      'eslint .'
    end

    def options
      {:format => 'json'}
    end

    def filtered_files(files)
      files.select do |file|
        file.end_with? '.js'
      end
    end
  end
end
