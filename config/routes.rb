require 'sidekiq/web'
require 'sidecloq/web'

MiqBot::Application.routes.draw do
  mount Sidekiq::Web, at: "/sidekiq"

  root 'main#index'

  get '/github_api_usage' => 'github_api_usage#index'
end
