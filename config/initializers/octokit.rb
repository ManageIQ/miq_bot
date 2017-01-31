Octokit.configure do |c|
  c.login    = Settings.github_credentials.username
  c.password = Settings.github_credentials.password
  c.auto_paginate = true

  rack_builder = Octokit::Default.middleware
  rack_builder.use GithubService::Response::RatelimitLogger
  c.middleware = rack_builder
end
