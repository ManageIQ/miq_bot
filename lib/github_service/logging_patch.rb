class GithubService
  module LoggingPatch
    def default_middleware(options = {})
      proc do |builder|
        super.call(builder)
        builder.insert_before ::Github::Response::RaiseError, GithubService::Response::RatelimitLogger, GithubService.logger
      end
    end
  end
end

Github::API.prepend(GithubService::LoggingPatch)
