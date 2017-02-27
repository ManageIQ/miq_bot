module GithubService
  class CommandDispatcher
    COMMANDS = Hash.new do |h, k|
      normalized = k.to_s.gsub("-", "_")            # Support - or _ in command
      normalized.chop! if normalized.end_with?("s") # Support singular or plural
      h[normalized]    if h.key?(normalized)
    end.merge(
      "add_label"     => :add_labels,
      "remove_label"  => :remove_labels,
      "rm_label"      => :remove_labels,
      "assign"        => :assign,
      "set_milestone" => :set_milestone
    ).freeze

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

        if method_name.empty?
          message = <<-EOMSG
@#{author} unrecognized command '#{command}', ignoring...

Accepted commands are: #{COMMANDS.keys.join(", ")}
          EOMSG
          issue.add_comment(message)
        else
          Rails.logger.info("Running command #{method_name}(#{command_value.inspect}, #{issue.author.inspect}, #{issue.number})")
          self.send(method_name, command_value, author, issue)
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

    def assign(user, author, issue)
      user       = user.strip
      clean_user = user.delete('@')

      if valid_assignee?(clean_user)
        issue.assign(clean_user)
      else
        issue.add_comment("@#{author} #{user} is an invalid assignee, ignoring...")
      end
    end

    def valid_assignee?(user)
      # First reload the cache if it's an invalid assignee
      GithubService.refresh_assignees(@fq_repo_name) unless GithubService.valid_assignee?(@fq_repo_name, user)

      # Then see if it's *still* invalid
      GithubService.valid_assignee?(@fq_repo_name, user)
    end

    def add_labels(command_value, author, issue)
      valid, invalid = extract_label_names(command_value)

      if invalid.any?
        message = "@#{author} Cannot apply the following label#{"s" if invalid.length > 1} because they are not recognized: "
        message << invalid.join(", ")
        issue.add_comment(message)
      end

      if valid.any?
        valid.reject!  { |l| issue.applied_label?(l) }
        issue.add_labels(valid)
      end
    end

    def remove_labels(command_value, author, issue)
      valid, invalid = extract_label_names(command_value)

      if invalid.any?
        message = "@#{author} Cannot remove the following label#{"s" if invalid.length > 1} because they are not recognized: "
        message << invalid.join(", ")
        issue.add_comment(message)
      end

      valid.each do |l|
        issue.remove_label(l) if issue.applied_label?(l)
      end
    end

    def extract_label_names(command_value)
      label_names = command_value.split(",").map { |label| label.strip.downcase }
      validate_labels(label_names)
    end

    def validate_labels(label_names)
      # First reload the cache if there are any invalid labels
      GithubService.refresh_labels(@fq_repo_name) unless label_names.all? { |l| GithubService.valid_label?(@fq_repo_name, l) }

      # Then see if any are *still* invalid and split the list
      label_names.partition { |l| GithubService.valid_label?(@fq_repo_name, l) }
    end
  end
end
