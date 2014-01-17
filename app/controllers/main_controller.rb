class MainController < ApplicationController
  def index
    @repos = CommitMonitorRepo.includes(:branches)
  end
end
