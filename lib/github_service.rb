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
      Array(comments).map do |comment|
        add_comment(fq_repo_name, issue_number, comment)
      end
    end

    # https://octokit.github.io/octokit.rb/Octokit/Client/Statuses.html#create_status-instance_method
    def add_status(fq_repo_name, commit_sha, comment_url, commit_state)
      repo    = fq_repo_name
      sha     = commit_sha
      options = {
        "context"    => Settings.github_credentials.username,
        "target_url" => comment_url,
      }

      case commit_state
      when :zero
        state = "success"
        options["description"] = "Everything looks fine."
      when :warn
        state = "success"
        options["description"] = "Some offenses detected."
      when :bomb
        state = "error"
        options["description"] = "Something went wrong."
      end

      create_status(repo, sha, state, options)
    end

    def delete_comments(fq_repo_name, comment_ids)
      Array(comment_ids).each do |comment_id|
        delete_comment(fq_repo_name, comment_id)
      end
    end

    # Deletes the issue comments found by the provided block, then creates new
    # issue comments from those provided.
    def replace_comments(fq_repo_name, issue_number, new_comments, status = nil, commit_sha = nil)
      raise "no block given" unless block_given?

      to_delete = issue_comments(fq_repo_name, issue_number).select { |c| yield c }
      delete_comments(fq_repo_name, to_delete.map(&:id))
      first_comment = add_comments(fq_repo_name, issue_number, new_comments).first

      # add_status creates a commit status pointing to the first comment URL
      if first_comment && status && commit_sha
        add_status(fq_repo_name, commit_sha, first_comment["html_url"], status)
      end
    end

    def issue(*args)
      Issue.new(service.issue(*args))
    end

    def list_issues(*args)
      service.list_issues(*args).map { |issue| Issue.new(issue) }
    end
    alias issues list_issues

    def search_issues(*args)
      service.search_issues(*args).items.map { |issue| Issue.new(issue) }
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
    # Note: This method creates labels on the repo if they don't exist, and assumes
    # that the labels being passed in have already been validated if you don't
    # want that behavior.
    #
    # For example, the notification monitor responds to users about any labels
    # being requested to be added that aren't valid, before calling this method.
    #
    def add_labels_to_an_issue(fq_repo_name, issue_number, requested_labels)
      issue(fq_repo_name, issue_number).add_labels(requested_labels)
    end

    # Overrides Octokit.remove_label
    # Github raises an exception if the label isn't present on the issue already.
    # This removes that error, making it a no-op, as Issue checks for the labels presence first.
    def remove_label(fq_repo_name, issue_number, label)
      issue(fq_repo_name, issue_number).remove_label(label)
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
      milestones_cache[fq_name] ||= Hash[service.list_milestones(fq_name, :state => :all).map { |m| [m.title, m.number] }]
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

    def username_lookup(username)
      if username_lookup_cache.key?(username)
        username_lookup_cache[username]
      else
        username_lookup_cache[username] ||= begin
          case Net::HTTP.new("github.com", 443).tap { |h| h.use_ssl = true }.request_head("/#{username}")
          when Net::HTTPNotFound then nil # invalid username
          when Net::HTTPOK       then service.user(username)[:id]
          else
            raise "Error on GitHub with username lookup"
          end
        end
      end
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

    def username_lookup_cache
      @username_lookup_cache ||= {}
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
