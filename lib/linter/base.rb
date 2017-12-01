module Linter
  class Base
    attr_reader :branch
    delegate :logger, :to => :branch

    def initialize(branch)
      @branch = branch
    end

    def run
      logger.info("#{log_header} Starting run...")
      if files_to_lint.empty?
        logger.info("#{log_header} Skipping run due to no candidate files.")
        return
      end

      require 'tempfile'
      result = Dir.mktmpdir do |dir|
        files = collected_config_files(dir)
        if files.blank?
          logger.error("#{log_header} Failed to run due to missing config files.")
          return failed_linter_offenses("missing config files")
        else
          files += collected_files_to_lint(dir)
          logger.info("#{log_header} Collected #{files.length} files.")
          logger.debug { "#{log_header} File list: #{files.inspect}"}
          run_linter(dir)
        end
      end

      offenses = parse_output(result.output)
      logger.info("#{log_header} Completed run with #{offenses.fetch_path('summary', 'offense_count')} offenses")
      logger.debug { "#{log_header} Offenses: #{offenses.inspect}" }
      offenses
    end

    private

    def parse_output(output)
      JSON.parse(output.chomp)
    rescue JSON::ParserError => error
      logger.error("#{log_header} #{error.message}")
      logger.error("#{log_header} Failed to parse JSON result #{output.inspect}")
      return failed_linter_offenses("error parsing JSON result")
    end

    def collected_config_files(dir)
      config_files.select { |path| extract_file(path, dir) }
    end

    def collected_files_to_lint(dir)
      files_to_lint.select { |path| extract_file(path, dir) }
    end

    def extract_file(path, destination_dir)
      content = branch_service.content_at(path)
      return false unless content

      temp_file = File.join(destination_dir, path)
      FileUtils.mkdir_p(File.dirname(temp_file))
      File.write(temp_file, content, :mode => "wb") # To prevent Encoding::UndefinedConversionError: "\xD0" from ASCII-8BIT to UTF-8
      true
    end

    def branch_service
      @branch_service ||= branch.git_service
    end

    def diff_service
      @diff_service ||= branch_service.diff
    end

    def files_to_lint
      @files_to_lint ||= begin
        unfiltered_files = branch.pull_request? ? diff_service.new_files : branch.git_service.tip_files
        filtered_files(unfiltered_files)
      end
    end

    def run_linter(dir)
      logger.info("#{log_header} Executing linter...")
      require 'awesome_spawn'
      AwesomeSpawn.run(linter_executable, :params => options, :chdir => dir).tap do |result|
        # rubocop exits 1 both when there are errors and when there are style issues.
        #   Instead of relying on just exit_status, we check if there is anything on stderr.
        raise result.error if result.exit_status != 0 && result.error.present?
      end
    end

    def failed_linter_offenses(message)
      {
        "files" => [
          {
            "path"     => "\\*\\*",
            "offenses" => [
              {
                "severity" => "fatal",
                "message"  => message,
                "cop_name" => self.class.name.titleize
              }
            ]
          }
        ],
        "summary" => {
          "offense_count"        => 1,
          "target_file_count"    => files_to_lint.length,
          "inspected_file_count" => files_to_lint.length
        }
      }
    end

    def log_header
      "#{self.class.name} Repo: #{branch.repo.name} Branch #{branch.name} -"
    end
  end
end
