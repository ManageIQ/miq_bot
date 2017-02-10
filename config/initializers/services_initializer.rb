unless Rails.env.test?
  BugzillaService.credentials = Settings.bugzilla_credentials
  PivotalService.credentials  = Settings.pivotal_credentials
end
