module GitHubApi
  class Issue
    attr_accessor :comments, :number, :body, :author, :created_at

    def initialize(octokit_issue, repo)
      @repo       = repo
      @repo_name  = repo.fq_repo_name
      @title      = octokit_issue.title
      @body       = octokit_issue.body
      @number     = octokit_issue.number
      @author     = octokit_issue.user.login
      @created_at = octokit_issue.created_at
      @client     = repo.client
    end

    def comments
      @comments ||= begin
        @octokit_comments = GitHubApi.execute(@client, :issue_comments, @repo_name, @number)
        @octokit_comments.collect do |octokit_comment|
          Comment.new(octokit_comment, self, @repo)
        end
      end
      return @comments
    end

    def assign(user)
      update("assignee" => user)
    end

    def set_milestone(milestone)
      update("milestone" => @repo.milestones[milestone])
    end

    def add_comment(message)
      GitHubApi.execute(@client, :add_comment, @repo_name, @number, message)
    end

    def applied_label?(label_text)
      applied_labels.include?(label_text)
    end

    def add_labels(labels_input)
      labels = labels_input.collect(&:text)
      GitHubApi.execute(@client, :add_labels_to_an_issue, @repo_name, @number, labels)

      labels.each do |l|
        applied_labels[l] = Label.new(@repo, l, self)
      end
    end

    def remove_label(label_name)
      applied_labels.delete(label_name)
      GitHubApi.execute(@client, :remove_label, @repo_name, @number, label_name)
    end

    def applied_labels
      @applied_labels ||= begin
        results = GitHubApi.execute(@client, :labels_for_issue, @repo_name, @number)
        results.each_with_object({}) do |result, h|
          h[result.name] = Label.new(@repo, result.name, self)
        end
      end
    end

    def title_indicates_wip?
      !!(@title =~ /\[WIP\]/i)
    end

    private

    def update(options)
      GitHubApi.execute(@client, :update_issue, @repo_name, @number, @title, @body, options)
    end
  end
end
