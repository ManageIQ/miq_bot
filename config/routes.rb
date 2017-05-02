require 'sidekiq/web'
require 'sidetiq/web'

MiqBot::Application.routes.draw do
  mount Sidekiq::Web, at: "/sidekiq"

  root 'main#index'

  get '/backport_requests'                                => 'backport_requests#index'
  get '/github_api_usage'                                 => 'github_api_usage#index'

  # Semantic Versioning Regex for API, i.e. vMajor.minor.patch[-pre]
  API_VERSION_REGEX = /v[\d]+(\.[\da-zA-Z]+)*(\-[\da-zA-Z]+)?/ unless defined?(API_VERSION_REGEX)

  namespace :api, :path => "api(/:version)", :version => API_VERSION_REGEX, :defaults => {:format => "json"} do
    root :to => "api#index"
  end
end
