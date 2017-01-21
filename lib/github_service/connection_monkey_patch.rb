require 'miq_tools_services/github/response/ratelimit_logger'

module Github
  module Connection
    alias orig_default_middleware default_middleware

    def default_middleware(options = {})
      proc do |builder|
        orig_default_middleware(options).call(builder)
        builder.insert_before ::Github::Response::RaiseError, MiqToolsServices::Github::Response::RatelimitLogger, MiqToolsServices::Github.logger
      end
    end
  end
end
