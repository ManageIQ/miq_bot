Listen.to(Rails.root.join("config"), :ignore => /github_notification_monitor\.yml/) do |*paths|
  begin
    Rails.logger.info "Reloading settings due to changes in #{paths.flatten.join(", ")}"
    Settings.reload!
  rescue => err
    Rails.logger.error "Unable to reload the settings!"
    Rails.logger.error err
  end
end.start
