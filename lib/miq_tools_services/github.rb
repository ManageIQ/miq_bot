module MiqToolsServices
  class Github
    include ServiceMixin

    class << self
      attr_accessor :credentials, :logger
    end
    delegate :credentials, :logger, :to => self

    def self.configure
      return if @configured

      ::Github.configure do |config|
        config.login           = credentials["username"]
        config.password        = credentials["password"]
        config.auto_pagination = true
      end

      @configured = true
    end

    def initialize(options)
      @options = options
      service # initialize the service
    end

    def service
      @service ||= begin
        require 'github_api'
        require 'miq_tools_services/github/connection_monkey_patch'
        self.class.configure
        ::Github.new(@options)
        # TODO: In the newer versions of github_api, use this instead of the monkey patch above
        # ::Github.new(@options) do |config|
        #   config.stack = proc do |builder|
        #     builder.insert_before ::Github::Response::RaiseError, Response::RatelimitLogger, logger
        #   end
        # end
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

    # Deletes the issue comments found by the provided block, then creates new
    # issue comments from those provided.
    def replace_issue_comments(issue_id, new_comments)
      raise "no block given" unless block_given?

      to_delete = select_issue_comments(issue_id) { |c| yield c }
      delete_issue_comments(to_delete.collect(&:id))
      create_issue_comments(issue_id, new_comments)
    end

    def issue_labels(issue_id)
      issues.labels.all(:issue_id => issue_id)
    end

    def issue_label_names(issue_id)
      issue_labels(issue_id).collect(&:name)
    end

    # Adds the labels specified, but only if they are not already on the issue.
    def add_issue_labels(issue_id, labels)
      old_labels = issue_label_names(issue_id)

      Array(labels).each do |label|
        next if old_labels.include?(label)
        issues.labels.add(user, repo, issue_id, label)
      end
    end
  end
end
