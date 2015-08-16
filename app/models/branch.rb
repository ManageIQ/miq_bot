class Branch < ActiveRecord::Base
  belongs_to :repo

  validates :name,        :presence => true, :uniqueness => {:scope => :repo}
  validates :commit_uri,  :presence => true
  validates :last_commit, :presence => true
  validates :repo,        :presence => true

  serialize :commits_list, Array

  default_value_for(:commits_list) { [] }
  default_value_for :mergeable, true

  delegate :enabled_for?, :to => :repo

  def self.with_branch_or_pr_number(n)
    n = MiqToolsServices::MiniGit.pr_branch(n) if n.kind_of?(Fixnum)
    where(:name => n)
  end

  def self.github_commit_uri(user, repo, sha = "$commit")
    "https://github.com/#{user}/#{repo}/commit/#{sha}"
  end

  def self.github_compare_uri(user, repo, sha1 = "$commit1", sha2 ="$commit2")
    "https://github.com/#{user}/#{repo}/compare/#{sha1}...#{sha2}"
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

  def compare_uri_for(commit1, commit2)
    # TODO: This needs use a different URI than the commit_uri
    commit_uri
      .gsub("/commit/", "/compare/")
      .gsub("$commit", "#{commit1}...#{commit2}")
  end

  def mode
    pull_request? ? :pr : :regular
  end

  def pr_number
    MiqToolsServices::MiniGit.pr_number(name) if pull_request?
  end

  def github_pr_uri
    return nil unless pull_request?
    "https://github.com/#{repo.fq_name}/pull/#{pr_number}"
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
