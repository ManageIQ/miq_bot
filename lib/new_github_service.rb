module NewGithubService
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
    def service
      @service ||= \
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

    # DEPRECATES GithubService.create_issue_comments
    def add_comments(fq_repo_name, issue_number, comments)
      Array(comments).each do |comment|
        add_comment(fq_repo_name, issue_number, comment)
      end
    end

    # DEPRECATES GithubService.delete_issue_comments
    def delete_comments(fq_repo_name, comment_ids)
      Array(comment_ids).each do |comment_id|
        delete_comment(fq_repo_name, comment_id)
      end
    end

    # Deletes the issue comments found by the provided block, then creates new
    # issue comments from those provided.
    # DEPRECATES GithubService.replace_issue_comments
    def replace_comments(fq_repo_name, issue_number, new_comments, &block)
      raise "no block given" unless block_given?

      to_delete = GithubService.issue_comments(fq_repo_name, issue_number).select { |c| yield c }
      delete_comments(fq_repo_name, to_delete.map(&:id))
      add_comments(fq_repo_name, issue_number, new_comments)
    end

    private

    def respond_to_missing?(method_name, include_private=false)
      service.respond_to?(method_name)
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
