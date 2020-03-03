if Settings.gitter_credentials && !Rails.env.test?
  require 'gitter_service'

  Gitter::Service.credentials = Settings.gitter_credentials
  Gitter::API.api_url         = Settings.gitter.api_url
  Gitter::API.api_prefix      = Settings.gitter.api_prefix || "/v1"
  Gitter::Bot.websocket_url   = Settings.gitter.websocket_url

  GITTER_BOT = Gitter::Bot.new do
    channels Settings.gitter.channels

    on "hello" do
      reply %w[Hello! Hi! Welcome!].sample
    end

    on "debug" do
      send_message <<~DEBUG
        **CMD**: `#{msg_cmd}`
        **ARGS**: `#{msg_args}`
      DEBUG
    end
  end
end
