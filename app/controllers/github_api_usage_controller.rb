class GithubApiUsageController < ApplicationController
  def index
  end

  def requests_remaining_measurements
    respond_to do |f|
      f.json do
        render :json => GithubUsageTracker.requests_remaining_measurements
      end
    end
  end
end
