module GithubService
  class CommandDispatcher
    COMMANDS = Hash.new do |h, k|
      normalized = k.to_s.gsub("-", "_")            # Support - or _ in command
      normalized.chop! if normalized.end_with?("s") # Support singular or plural
      h[normalized]    if h.key?(normalized)
    end.merge(
      "set_milestone" => :set_milestone
    ).freeze

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
        method_name   = COMMANDS[command].to_s
        command_class = self.class.registry[command]

        if method_name.present?
          Rails.logger.info("Running command #{method_name}(#{command_value.inspect}, #{issue.author.inspect}, #{issue.number})")
          self.send(method_name, command_value, author, issue)
        elsif command_class.present?
          command_class.new(issue).execute!(issuer: author, value: command_value)
        else
          message = <<-EOMSG
@#{author} unrecognized command '#{command}', ignoring...

Accepted commands are: #{COMMANDS.keys.join(", ")}
          EOMSG
          issue.add_comment(message)
        end
      end
    end

    private

    def set_milestone(milestone, author, issue)
      milestone = milestone.strip

      if valid_milestone?(milestone)
        issue.set_milestone(milestone)
      else
        message = "@#{author} Milestone #{milestone} is not recognized, ignoring..."
        issue.add_comment(message)
      end
    end

    def valid_milestone?(milestone)
      # First reload the cache if it's an invalid milestone
      GithubService.refresh_milestones(@fq_repo_name) unless GithubService.valid_milestone?(@fq_repo_name, milestone)

      # Then see if it's *still* invalid
      GithubService.valid_milestone?(@fq_repo_name, milestone)
    end
  end
end
