class CommitMonitorBranch < ActiveRecord::Base
  belongs_to :repo, :class_name => :CommitMonitorRepo, :foreign_key => :commit_monitor_repo_id

  validates :name,        :presence => true, :uniqueness => {:scope => :repo}
  validates :commit_uri,  :presence => true
  validates :last_commit, :presence => true
  validates :repo,        :presence => true

  serialize :commits_list, Array

  default_value_for(:commits_list) { [] }
  default_value_for :mergeable, true

  def self.github_commit_uri(user, repo, sha = "$commit")
    "https://github.com/#{user}/#{repo}/commit/#{sha}"
  end

  def last_commit=(val)
    super
    self.last_changed_on = Time.now.utc if last_commit_changed?
  end

  def commit_uri_to(commit)
    commit_uri.gsub("$commit", commit)
  end

  def last_commit_uri
    commit_uri_to(last_commit)
  end

  def pr_number
    CFMEToolsServices::MiniGit.pr_number(name) if pull_request?
  end
end
