require 'rubocop'

module Linter
  class Rubocop
    def initialize(branch)
      @branch = branch
    end

    def run
      require 'tempfile'
      result = Dir.mktmpdir do |dir|
        @work_dir = File.join(dir, "rubocop")
        Dir.mkdir(@work_dir)
        collect_files

        options = {:format => 'json'}
        @branch.logger.info("Executing: #{AwesomeSpawn.build_command_line('rubocop', options)}")
        require 'awesome_spawn'
        result = AwesomeSpawn.run('rubocop', :params => options, :chdir => @work_dir)
      end

      # rubocop exits 1 both when there are errors and when there are style issues.
      #   Instead of relying on just exit_status, we check if there is anything on stderr.
      raise result.error if result.exit_status != 0 && result.error.present?
      JSON.parse(result.output.chomp)
    end

    private

    def collect_files
      branch_service   = @branch.git_service
      diff_service     = branch_service.diff
      files_to_rubocop = filtered_files(diff_service.new_files)

      (files_to_rubocop + [".rubocop.yml"]).each do |path|
        blob = branch_service.blob_at(path)
        next unless blob
        temp_file = File.join(@work_dir, path)
        FileUtils.mkdir_p(File.dirname(temp_file))
        File.write(temp_file, blob.content.to_s)
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
  end
end
