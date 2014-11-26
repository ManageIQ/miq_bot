unless Rails.env.test?
  MiqToolsServices::Bugzilla.credentials = Settings.bugzilla_credentials
  MiqToolsServices::Github.credentials   = Settings.github_credentials
end
