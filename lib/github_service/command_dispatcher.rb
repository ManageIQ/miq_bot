module GithubService
  class CommandDispatcher
    class << self
      def registry
        @registry ||= Hash.new do |h, k|
          normalized = k.to_s.tr("-", "_")              # Support - or _ in command
          normalized.chop! if normalized.end_with?("s") # Support singular or plural
          h[normalized]    if h.key?(normalized)
        end
      end

      def register_command(command_name, command_class)
        registry[command_name.to_s] = command_class
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

        command       = match[:command]
        command_value = match[:command_value]
        command_class = self.class.registry[command]

        if command_class.present?
          Rails.logger.info("Dispatching '#{command}' to #{command_class} on issue ##{issue.number} | issuer: #{issuer}, value: #{command_value}")
          command_class.new(issue).execute!(:issuer => issuer, :value => command_value)
        else
          message = <<-EOMSG
@#{issuer} unrecognized command '#{command}', ignoring...

Accepted commands are: #{self.class.registry.keys.join(", ")}
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
      @bot_name ||= Settings.github_credentials.username
    end
  end
end
