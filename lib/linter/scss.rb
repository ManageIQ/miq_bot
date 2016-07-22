module Linter
  class SCSS < Base
    private

    def config_files
      [".scss-lint.yml"]
    end

    def linter_executable
      'scss-lint'
    end

    def options
      {:format => 'JSON'}
    end

    def filtered_files(files)
      files.select { |file| file.end_with?(".scss") }
    end
  end
end
