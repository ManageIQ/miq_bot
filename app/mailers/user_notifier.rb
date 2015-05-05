class UserNotifier < ActionMailer::Base
  default :from => 'any_from_address@example.com'

  # Send notification email about a new issue
  def send_notification_email(email, issue, label)
    @email = email
    @issue = issue
    @label = label
    mail( :to => @email,
          :subject => "New issue (#{issue}) labeled #{label} created" )
  end
end