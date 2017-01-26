require 'sidekiq/web'
require 'sidetiq/web'

MiqBot::Application.routes.draw do
  mount Sidekiq::Web, at: "/sidekiq"

  root 'main#index'

  get '/backport_requests'                                => 'backport_requests#index'
  get '/github_api_usage'                                 => 'github_api_usage#index'
  get '/github_api_usage/requests_remaining_measurements' => 'github_api_usage#requests_remaining_measurements'
end
