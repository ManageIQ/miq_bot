module GithubService
  ##
  # GithubService is miq-bot's interface to the Github API. It acts as a
  # wrapper around Octokit, delegating calls directly to the Octokit client as
  # well as providing a space to keep useful augmentations of the interface for
  # our own use cases.
  #
  # You can find the official Octokit documentation at http://octokit.github.io/octokit.rb
  #
  # Please check the documentation first before adding helper methods, as they
  # may already be well handled by Octokit itself.
  #
  class << self
    def add_comments(fq_repo_name, issue_number, comments)
      Array(comments).each do |comment|
        add_comment(fq_repo_name, issue_number, comment)
      end
    end

    def delete_comments(fq_repo_name, comment_ids)
      Array(comment_ids).each do |comment_id|
        delete_comment(fq_repo_name, comment_id)
      end
    end

    # Deletes the issue comments found by the provided block, then creates new
    # issue comments from those provided.
    def replace_comments(fq_repo_name, issue_number, new_comments)
      raise "no block given" unless block_given?

      to_delete = issue_comments(fq_repo_name, issue_number).select { |c| yield c }
      delete_comments(fq_repo_name, to_delete.map(&:id))
      add_comments(fq_repo_name, issue_number, new_comments)
    end

    def issue(*args)
      Issue.new(service.issue(*args))
    end

    def issue_comments(*args)
      service.issue_comments(*args).map do |comment|
        IssueComment.new(comment)
      end
    end

    def repository_notifications(*args)
      service.repository_notifications(*args).map do |notification|
        Notification.new(notification)
      end
    end

    # Overrides Octokit.add_labels_to_an_issue
    # Github automatically creates a label for the repo if it does not exist.
    # This requires you to opt-in to that behavior.
    def add_labels_to_an_issue(fq_repo_name, issue_number, requested_labels, create_if_missing: false)
      labels_to_add = requested_labels

      unless create_if_missing
        requested_labels.each do |label|
          unless valid_label?(fq_repo_name, label)
            logger.warn "The label '#{label}' was attempted to be added to #{fq_repo_name} ##{issue_number}, but that label doesn't exist on the repo."
            labels_to_add.delete(label)
          end
        end
      end

      service.add_labels_to_an_issue(repo, issue_number, labels_to_add)
    end

    def labels(fq_name)
      labels_cache[fq_name] ||= Set.new(service.labels(fq_name).map(&:name))
    end

    def valid_label?(fq_name, label_text)
      labels(fq_name).include?(label_text)
    end

    def refresh_labels(fq_name)
      labels_cache.delete(fq_name)
    end

    def milestones(fq_name)
      milestones_cache[fq_name] ||= Hash[service.list_milestones(fq_name).map { |m| [m.title, m.number] }]
    end

    def valid_milestone?(fq_name, milestone)
      milestones(fq_name).include?(milestone)
    end

    def refresh_milestones(fq_name)
      milestones_cache.delete(fq_name)
    end

    def assignees(fq_name)
      assignees_cache[fq_name] ||= Set.new(service.repo_assignees(fq_name).map(&:login))
    end

    def valid_assignee?(fq_name, user)
      assignees(fq_name).include?(user)
    end

    def refresh_assignees(fq_name)
      assignees_cache.delete(fq_name)
    end

    private

    def service
      @service ||=
        begin
          require 'octokit'

          unless Rails.env.test?
            Octokit.configure do |c|
              c.login    = Settings.github_credentials.username
              c.password = Settings.github_credentials.password
              c.auto_paginate = true

              c.middleware = Faraday::RackBuilder.new do |builder|
                builder.use GithubService::Response::RatelimitLogger
                builder.use Octokit::Response::RaiseError
                builder.use Octokit::Response::FeedParser
                builder.adapter Faraday.default_adapter
              end
            end
          end

          Octokit::Client.new
        end
    end

    def labels_cache
      @labels_cache ||= {}
    end

    def milestones_cache
      @milestones_cache ||= {}
    end

    def assignees_cache
      @assignees_cache ||= {}
    end

    def respond_to_missing?(method_name, include_private = false)
      service.respond_to?(method_name, include_private)
    end

    def method_missing(method_name, *args, &block)
      if service.respond_to?(method_name)
        service.send(method_name, *args, &block)
      else
        super
      end
    end
  end
end
