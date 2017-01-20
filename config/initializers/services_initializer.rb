unless Rails.env.test?
  BugzillaService.credentials = Settings.bugzilla_credentials
  GithubService.credentials   = Settings.github_credentials
  PivotalService.credentials  = Settings.pivotal_credentials

  GithubService.logger = Sidekiq::Logging.logger
end
