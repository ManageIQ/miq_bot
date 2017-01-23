module Github
  module Connection
    alias orig_default_middleware default_middleware

    def default_middleware(options = {})
      proc do |builder|
        orig_default_middleware(options).call(builder)
        builder.insert_before ::Github::Response::RaiseError, GithubService::Response::RatelimitLogger, GithubService.logger
      end
    end
  end
end
