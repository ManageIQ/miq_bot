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
