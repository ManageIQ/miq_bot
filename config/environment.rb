# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
MiqBot::Application.initialize!

# Action
ActionMailer::Base.smtp_settings = {
    :user_name => 'username',
    :password => 'password',
    :domain => 'yourdomain.com',
    :address => 'smtp.domain.com',
    :port => 587,
    :authentication => :plain,
    :enable_starttls_auto => true
}