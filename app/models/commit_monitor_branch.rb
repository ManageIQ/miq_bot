class CommitMonitorBranch < ActiveRecord::Base
  belongs_to :repo, :class_name => :CommitMonitorRepo, :foreign_key => :commit_monitor_repo_id

  validates :name,        :presence => true, :uniqueness => {:scope => :repo}
  validates :commit_uri,  :presence => true
  validates :last_commit, :presence => true
  validates :repo,        :presence => true

  serialize :commits_list, Array

  default_value_for(:commits_list) { [] }
  default_value_for :mergeable, true

  def self.with_branch_or_pr_number(n)
    n = MiqToolsServices::MiniGit.pr_branch(n) if n.kind_of?(Fixnum)
    where(:name => n)
  end

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
    MiqToolsServices::MiniGit.pr_number(name) if pull_request?
  end

  def write_github_comment(header, continuation_header = nil, message = nil)
    unless pull_request?
      raise ArgumentError, "Cannot comment on non-pull request branches such as #{name}."
    end

    message_builder = MiqToolsServices::Github::MessageBuilder.new(header, continuation_header)
    message_builder.write(message) if message

    logger.info("#{__method__} Writing comment with header: #{header}")
    repo.with_github_service do |github|
      # TODO: Refactor the common "delete prior tagged issues" into miq_tools_services
      # github.delete_issue_comments(pr_number, header)
      github.create_issue_comments(pr_number, message_builder.comments)
    end
  end
end
