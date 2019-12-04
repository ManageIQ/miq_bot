require 'octokit'
require 'github_service'
require 'github_service/issue'

module GithubServiceHelper
  module_function

  # Helper method for configuring the stubs for the GithubService's @service
  # (Octokit::Client) variable.
  #
  # Can be configured in the rspec instance as follows:
  #
  #   github_service_stubs do |stub|
  #     # stub getting issue 1234
  #     issue_url = '/repos/ManageIQ/manageiq-cross_repo-tests/issues/1234'
  #     stub.get(issues_url, default_octokit_headers) do |env|
  #        [200, github_service_response_headers, '{}']
  #     end
  #   end
  #
  #   # stub creating a new PR on ManageIQ/manageiq-cross_repo-tests
  #   new_pr_url = '/repos/ManageIQ/manageiq-cross_repo-tests/pulls'
  #   github_service_stubs.post(new_pr_url, nil, headers) do |env|
  #      [
  #        200,                              # response status
  #        github_service_response_headers,  # response headers
  #        {                                 # response body
  #          "id" => 1,
  #          # ...
  #        }.to_json
  #      ]
  #   end
  #
  def github_service_stubs(&block)
    GithubService.octokit_stubs(&block)
  end

  # Convenience wrapper method for adding a new Octokit stub.
  #
  # Defaults method, headers, requests/response to sensible defaults
  #
  # Equivalents to the above examples:
  #
  #   issue_url = '/repos/ManageIQ/manageiq-cross_repo-tests/issues/1234'
  #   github_service_add_stub :url => issue_url
  #
  #   new_pr_url = '/repos/ManageIQ/manageiq-cross_repo-tests/pulls'
  #   github_service_add_stub :url           => issue_url
  #                           :method        => :post
  #                           :response_body => {"id" => 1}.to_json
  #
  def github_service_add_stub(options = {})
    url = options[:url] || options[:path]
    raise "options[:url] is required for github_service_add_stub!" unless url

    request_method   = options[:method]           || :get
    request_body     = options[:request_body]     || nil
    request_headers  = options[:request_headers]  || default_octokit_headers
    response_status  = options[:response_status]  || 200
    response_body    = options[:response_body]    || "{}"
    response_headers = options[:response_headers] || github_service_response_headers

    github_service_stubs.send(:new_stub, request_method, url, request_headers, request_body) do
      [response_status, response_headers, response_body]
    end
  end

  # Removes any previous stubs made.
  #
  # Useful when overriding a default stub higher up in a rspec context.
  #
  # Note: Reaches a bit into the private instance variables on the Faraday
  # adapter to do this... but it is what is available...
  #
  def clear_previous_github_service_stubs!
    github_service_stubs.instance_variable_set(:@stack, {})
  end

  # Removes all stubs for a given HTTP method and URL.
  #
  # Note: Like the above method, requires the use of the internal API... sorry
  # not sorry.
  #
  def clear_stubs_for!(method, url)
    stack = github_service_stubs.instance_variable_get(:@stack)
    return unless stack.key?(method)

    stack[method].delete_if { |stub| stub.path == url }
  end

  # Enough response data to work with the `GithubService::Issue` object, but
  # will always be a "Issue", not a Pull Request (since there is no
  # "pull_request" data returned).
  #
  # Based on https://developer.github.com/v3/issues/#get-a-single-issue
  #
  def single_issue_request_response(fq_repo_name, issue_id)
    repository_url = "https://api.github.com/repos/#{fq_repo_name}"
    {
      "id"             => issue_id,
      "url"            => "https://api.github.com/repos/#{fq_repo_name}/issues/#{issue_id}",
      "number"         => issue_id,
      "repository_url" => repository_url,
      "labels"         => [
        {"name" => "bug"},
        {"name" => "wip"}
      ]
    }.to_json
  end

  # Enough response data to work with the `GithubService::Issue object
  #
  # Based on https://developer.github.com/v3/issues/#get-a-single-issue
  #
  def single_pull_request_response(fq_repo_name, pull_request_id)
    repository_url = "https://api.github.com/repos/#{fq_repo_name}"
    {
      "id"             => pull_request_id,
      "url"            => "https://api.github.com/repos/#{fq_repo_name}/pulls/#{pull_request_id}",
      "number"         => pull_request_id,
      "repository_url" => repository_url,
      "labels"         => [
        {"name" => "bug"},
        {"name" => "wip"}
      ],
      "pull_request"   => {
        "url" => "#{repository_url}/pulls/#{pull_request_id}"
      }
    }.to_json
  end

  # Required headers so Sawyer will parse the json properly
  def github_service_response_headers
    {"Content-Type" => "application/json"}
  end

  # Default headers that are configured and sent by Octokit
  #
  # The exception here would be 'Accept-Encoding', which is the defaulted in
  # `net/http`, and is configured in the initializer for
  # `Net::HTTPGenericRequest`.
  #
  # However, since we are using the `Faraday::Adapter::Test` for our
  # `Octokit::Client`, this is actually not configured here.
  #
  def default_octokit_headers
    {
      :accept       => ::Octokit::Default.default_media_type,
      :content_type => "application/json",
      :user_agent   => ::Octokit::Default.user_agent
      # :accept_encoding => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3"
    }
  end
end

# Override the `GithubService.service` to use a stub faraday test adapter
#
module GithubService
  class << self
    # Used by rspec after filter to clear out any previous stubbing
    #
    # Can be called manually if necessary to reset the test stubs
    def unset_service_vars!
      @service       = nil
      @octokit_stubs = nil
    end

    # A Faraday::Adapter::Test::Stubs instance to be used with the "test version"
    # of the `.service` (Octokit::Client) below
    #
    def octokit_stubs(&block)
      block          ||= proc { |stubs| stubs }
      @octokit_stubs ||= Faraday::Adapter::Test::Stubs.new(&block)
    end

    private

    def service
      @service ||=
        begin
          Octokit.configure do |c|
            # TODO:  Determine if this is needed for specs
            #
            # c.login    = Settings.github_credentials.username
            # c.password = Settings.github_credentials.password
            c.auto_paginate = true

            c.middleware = Faraday::RackBuilder.new do |builder|
              builder.use Octokit::Response::RaiseError
              # builder.response :logger  # uncomment for debugging
              builder.adapter :test, octokit_stubs
            end
          end

          Octokit::Client.new
        end
    end
  end
end

RSpec.configure do |config|
  config.include GithubServiceHelper

  config.after do
    GithubService.unset_service_vars!
  end
end
