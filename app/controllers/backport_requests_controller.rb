class BackportRequestsController < ApplicationController
  def index
    @target_branch = params[:target_branch]
    @backport_requests = Backporting.search_for_backport_requests(@target_branch)
  end
end
