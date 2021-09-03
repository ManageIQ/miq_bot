unless Rails.env.test?
  PivotalService.credentials  = Settings.pivotal_credentials
end
