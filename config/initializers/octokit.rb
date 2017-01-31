Octokit.configure do |c|
  c.login    = Settings.github_credentials.username
  c.password = Settings.github_credentials.password
  c.auto_paginate = true
end
