require 'faraday'

class GithubService
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
        api_calls_remaining = env.response_headers['x-ratelimit-remaining']
        logger.info { "Executed #{env.method.to_s.upcase} #{env.url}...api calls remaining #{api_calls_remaining}" }
        GithubUsageTracker.record_datapoint(
          :requests_remaining => api_calls_remaining,
          :timestamp          => DateTime.parse(env.response_headers["date"])
        )
      end
    end
  end
end
