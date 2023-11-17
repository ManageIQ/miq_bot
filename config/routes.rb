require 'sidekiq/web'
require 'sidecloq/web'

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  mount Sidekiq::Web, at: "/sidekiq"

  root 'main#index'

  get '/github_api_usage' => 'github_api_usage#index'
end
