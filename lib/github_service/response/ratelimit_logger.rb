require 'faraday'

module GithubService
  module Response
    class RatelimitLogger < Faraday::Middleware
      attr_accessor :logger

      def initialize(app, logger = nil)
        super(app)
        @logger = logger || begin
          require 'logger'
          ::Logger.new(STDOUT)
        end
      end

      def on_complete(env)
        api_calls_remaining = env.response_headers['x-ratelimit-remaining']
        logger.info { "Executed #{env.method.to_s.upcase} #{env.url}...api calls remaining #{api_calls_remaining}" }
      end
    end
  end
end
