require 'thread'
require 'github_api'

class GithubService
  include ServiceMixin

  def self.configure
    return if @configured

    Github.configure do |config|
      config.login           = credentials["username"]
      config.password        = credentials["password"]
      config.auto_pagination = true
    end

    @configured = true
  end

  def initialize(options)
    @options = options.dup

    if @options[:repo].kind_of?(CommitMonitorRepo)
      @options[:user] = @options[:repo].upstream_user
      @options[:repo] = @options[:repo].name
    end

    service # initialize the service
  end

  def service
    @service ||= begin
      self.class.configure
      Github.new(@options)
    end
  end

  def select_issue_comments(issue_id)
    raise "no block given" unless block_given?
    issues.comments.all(:issue_id => issue_id).select { |c| yield c }
  end

  def create_issue_comments(issue_id, comments)
    Array(comments).each do |comment|
      issues.comments.create(
        :issue_id => issue_id,
        :body     => comment
      )
    end
  end

  def edit_issue_comment(comment_id, comment)
    issues.comments.edit(
      :comment_id => comment_id,
      :body       => comment
    )
  end

  def delete_issue_comments(comment_ids)
    Array(comment_ids).each do |comment_id|
      issues.comments.delete(:comment_id => comment_id)
    end
  end

  private

  def self.credentials
    @credentials ||= YAML.load_file(Rails.root.join('config/github_credentials.yml'))
  end

  private_class_method :credentials
end
