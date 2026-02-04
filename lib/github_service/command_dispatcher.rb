module GithubService
  class CommandDispatcher
    class << self
      def find_command_class(command_name)
        # Normalize the command name: support - or _, and singular or plural
        normalized = command_name.to_s.tr("-", "_")
        normalized.chop! if normalized.end_with?("s")

        command_classes.detect { |klass| klass.match_command?(normalized) }
      end

      def available_commands
        command_classes.map(&:command_name).sort
      end

      def command_classes
        @command_classes ||= begin
          Rails.application.autoloaders.main.eager_load_dir(File.expand_path("commands", __dir__))
          GithubService::Commands::Base.descendants
        end
      end
    end

    attr_reader :issue

    def initialize(issue)
      @issue = issue.kind_of?(GithubService::Issue) ? issue : GithubService::Issue.new(issue)
      @fq_repo_name = @issue.fq_repo_name
    end

    def dispatch!(issuer:, text:)
      lines = text.split("\n")
      lines.each do |line|
        match = command_regex.match(line.strip)
        next unless match
        next if issuer == bot_name

        command       = match[:command]
        command_value = match[:command_value]
        command_class = self.class.find_command_class(command)

        if command_class.present?
          Rails.logger.info("Dispatching '#{command}' to #{command_class} on issue ##{issue.number} | issuer: #{issuer}, value: #{command_value}")
          command_class.new(issue).execute!(:issuer => issuer, :value => command_value)
        else
          message = <<~EOMSG
            @#{issuer} unrecognized command '#{command}', ignoring...

            Accepted commands are: #{self.class.available_commands.join(", ")}
          EOMSG
          issue.add_comment(message)
        end
      end
    end

    private

    def command_regex
      /\A@#{bot_name}\s+(?<command>[a-z_-]+)(?:\s*)(?<command_value>.*)\z/i
    end

    def bot_name
      GithubService.bot_name
    end
  end
end
