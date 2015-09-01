unless Rails.env.test?
  MiqToolsServices::Bugzilla.credentials = Settings.bugzilla_credentials
  MiqToolsServices::Github.credentials   = Settings.github_credentials
  MiqToolsServices::Trello.credentials   = Settings.trello.credentials.basic_auth
end
