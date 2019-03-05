unless Rails.env.test?
  BugzillaService.credentials = Settings.bugzilla_credentials
  BugzillaService.product     = Settings.bugzilla.product
  PivotalService.credentials  = Settings.pivotal_credentials
end
