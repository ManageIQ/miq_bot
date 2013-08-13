require_relative 'git_hub_api'

module GitHubApi

  class Issue

    attr_accessor :comments, :number

    def initialize(octokit_issue, repo)
      @repo       = repo
      @repo_name  = repo.fq_repo_name
      @title      = octokit_issue.title
      @body       = octokit_issue.body
      @number     = octokit_issue.number
      @client     = repo.client
      load_applied_labels
    end

    def comments
      @comments ||= begin
        @octokit_comments = @client.issue_comments(@repo_name, @number)
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
      @client.add_comment(@repo_name, @number, message)
    end

    def applied_label?(label_text)
      @applied_labels.include?(label_text)
    end

    def add_labels(labels_input)
      labels = labels_input.collect(&:text)
      @client.add_labels_to_an_issue(@repo_name, @number, labels)
    end

    def remove_label(label_name)
      @applied_labels.delete(label_name)
      @client.remove_label(@repo_name, @number, label_name)  
    end

    private

    def load_applied_labels
      @applied_labels = Hash.new 
      results = @client.labels_for_issue(@repo_name, @number)
      results.each do |result| 
        label = GitHubApi::Label.new(@repo, result.name, self) 
        @applied_labels[result.name] = label
      end
    end

    def update(options)
      @client.update_issue(@repo_name, @number, @title, @body, options)
    end

  end
end