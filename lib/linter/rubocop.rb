require 'rubocop'

module Linter
  class Rubocop < Base
    private

    def config_files
      [".rubocop.yml", ".rubocop_base.yml", ".rubocop_local.yml"]
    end

    def linter_executable
      'rubocop'
    end

    def options
      {:format => 'json'}
    end

    def filtered_files(files)
      files.select do |file|
        file.end_with?(".rb") ||
          file.end_with?(".ru") ||
          file.end_with?(".rake") ||
          File.basename(file).in?(%w(Gemfile Rakefile))
      end.reject do |file|
        file.end_with?("db/schema.rb")
      end
    end
  end
end
