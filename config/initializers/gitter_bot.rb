if Settings.gitter_credentials and not Rails.env.test?
  require 'gitter_service'

  Gitter::Service.credentials = Settings.gitter_credentials

  GITTER_BOT = Gitter::Bot.new do
    channels Settings.gitter.channels
  end
end
