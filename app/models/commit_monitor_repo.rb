class CommitMonitorRepo < ActiveRecord::Base
  has_many :branches, :class_name => :CommitMonitorBranch, :dependent => :destroy

  validates :name, :presence => true, :uniqueness => true
  validates :path, :presence => true, :uniqueness => true

  def path=(val)
    super(File.expand_path(val))
  end

  def with_git_service
    raise "no block given" unless block_given?
    GitService.call(path) { |git| yield git }
  end
end
