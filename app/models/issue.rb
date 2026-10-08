class Issue < ActiveRecord::Base
  belongs_to :repo

  validates :number, :presence => true
  validates :number, :uniqueness => {:scope => :repo_id}
end
