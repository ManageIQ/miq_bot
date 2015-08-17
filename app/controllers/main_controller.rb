class MainController < ApplicationController
  def index
    @branches = Branch.includes(:repo).sort_by { |b| [b.repo.name, b.name] }
  end
end
