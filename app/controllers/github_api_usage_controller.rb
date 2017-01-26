class GithubApiUsageController < ApplicationController
  def index
  end

  def rate_limit_measurements
    respond_to do |f|
      f.json do
        render :json => GithubUsageTracker.rate_limit_measurements
      end
    end
  end
end
