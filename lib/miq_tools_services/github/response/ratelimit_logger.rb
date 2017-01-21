require 'faraday'

module MiqToolsServices
  class Github
    module Response
      class RatelimitLogger < Faraday::Response::Middleware
        attr_accessor :logger

        def initialize(app, logger = nil)
          super(app)
          @logger = logger || begin
            require 'logger'
            ::Logger.new(STDOUT)
          end
        end

        def on_complete(env)
          logger.info { "Executed #{env.method.to_s.upcase} #{env.url}...api calls remaining #{env.response_headers['x-ratelimit-remaining']}" }
        end
      end
    end
  end
end
