require 'rubocop'

module Linter
  class Rubocop
    attr_reader :branch
    delegate :logger, :to => :branch

    def initialize(branch)
      @branch = branch
    end

    def run
      logger.info("#{log_header} Starting Rubocop run...")
      require 'tempfile'
      result = Dir.mktmpdir do |dir|
        @work_dir = File.join(dir, "rubocop")
        Dir.mkdir(@work_dir)
        collect_files
        logger.info("#{log_header} Collected files #{Dir.glob(File.join(@work_dir, "**/*")).inspect}")

        options = {:format => 'json'}
        logger.info("#{log_header} Executing: #{AwesomeSpawn.build_command_line('rubocop', options)}")
        require 'awesome_spawn'
        result = AwesomeSpawn.run('rubocop', :params => options, :chdir => @work_dir)
      end

      # rubocop exits 1 both when there are errors and when there are style issues.
      #   Instead of relying on just exit_status, we check if there is anything on stderr.
      raise result.error if result.exit_status != 0 && result.error.present?
      begin
        offenses = JSON.parse(result.output.chomp)
      rescue JSON::ParserError => error
        logger.error("#{log_header} #{error.message}")
        logger.error("#{log_header} Failed to parse JSON result #{result.output.inspect}")
      end
      logger.info("#{log_header} Completed Rubocop run with offenses #{offenses.inspect}")
      offenses
    end

    private

    def collect_files
      branch_service   = branch.git_service
      diff_service     = branch_service.diff
      files_to_rubocop = filtered_files(diff_service.new_files)

      (files_to_rubocop + [".rubocop.yml"]).each do |path|
        blob = branch_service.blob_at(path)
        next unless blob
        temp_file = File.join(@work_dir, path)
        FileUtils.mkdir_p(File.dirname(temp_file))
        File.write(temp_file, blob.content.to_s, :mode => "wb") # To prevent Encoding::UndefinedConversionError: "\xD0" from ASCII-8BIT to UTF-8
      end
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

    def log_header
      "#{self.class.name} Branch #{branch.name} -"
    end
  end
end
