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
      @bot_name = Settings.github_credentials.username
      @fq_repo_name = @issue.fq_repo_name
    end

    def dispatch!(author:, text:)
      lines = text.split("\n")
      lines.each do |line|
        match = line.strip.match(/^@#{@bot_name}\s+([-@a-z0-9_]+)\s+/i)
        next unless match

        command       = match.captures.first
        command_value = match.post_match
        command_class = self.class.registry[command]

        if command_class.present?
          Rails.logger.info("Dispatching '#{command}' to #{command_class} on issue ##{issue.number} | issuer: #{author}, value: #{command_value}")
          command_class.new(issue).execute!(issuer: author, value: command_value)
        else
          message = <<-EOMSG
@#{author} unrecognized command '#{command}', ignoring...

Accepted commands are: #{self.class.registry.keys.join(", ")}
          EOMSG
          issue.add_comment(message)
        end
      end
    end
  end
end
