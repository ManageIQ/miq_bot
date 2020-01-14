class Branch < ActiveRecord::Base
  belongs_to :repo

  validates :name,        :presence => true, :uniqueness => {:scope => :repo}
  validates :commit_uri,  :presence => true
  validates :last_commit, :presence => true
  validates :repo,        :presence => true

  serialize :commits_list, Array

  default_value_for(:commits_list) { [] }
  default_value_for :mergeable, true
  default_value_for :pull_request, false

  after_initialize(:unless => :commit_uri) { self.commit_uri = self.class.github_commit_uri(repo.try(:name)) }

  scope :regular_branches, -> { where(:pull_request => [false, nil]) }
  scope :pr_branches,      -> { where(:pull_request => true) }

  def self.with_branch_or_pr_number(n)
    n = MinigitService.pr_branch(n) if n.kind_of?(Fixnum)
    where(:name => n)
  end

  def self.github_commit_uri(repo_name, sha = "$commit")
    "https://github.com/#{repo_name}/commit/#{sha}"
  end

  def self.github_compare_uri(repo_name, sha1 = "$commit1", sha2 ="$commit2")
    "https://github.com/#{repo_name}/compare/#{sha1}~...#{sha2}"
  end

  def self.github_pr_uri(repo_name, pr_number = "$pr_number")
    "https://github.com/#{repo_name}/pull/#{pr_number}"
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

  def local_merge_target
    "origin/#{merge_target}"
  end

  def compare_uri_for(commit1, commit2)
    # TODO: This needs use a different URI than the commit_uri
    commit_uri
      .gsub("/commit/", "/compare/")
      .gsub("$commit", "#{commit1}~...#{commit2}")
  end

  def mode
    pull_request? ? :pr : :regular
  end

  def pr_number
    MinigitService.pr_number(name) if pull_request?
  end

  def fq_pr_number
    "#{fq_repo_name}##{pr_number}" if pull_request?
  end

  def pr_title_tags
    pr_title.to_s.match(/^(?:\s*\[\w+\])+/).to_s.gsub("[", " [").split.map { |s| s[1...-1] }
  end

  def github_pr_uri
    self.class.github_pr_uri(repo.name, pr_number) if pull_request?
  end

  def write_github_comment(header, continuation_header = nil, message = nil)
    raise ArgumentError, "Cannot comment on non-PR branch #{name}." unless pull_request?

    message_builder = GithubService::MessageBuilder.new(header, continuation_header)
    message_builder.write(message) if message

    logger.info("Writing comment with header: #{header}")
    GithubService.add_comments(repo.name, pr_number, message_builder.comments)
  end

  def fq_repo_name
    repo.name
  end

  def fq_branch_name
    "#{fq_repo_name}@#{name}"
  end

  def git_service
    GitService::Branch.new(self)
  end

  # Branch Failure

  def notify_of_failure
    if passing?
      BuildFailureNotifier.new(self).report_passing
      update(:last_build_failure_notified_at => nil, :travis_build_failure_id => nil)
    elsif should_notify_of_failure?
      update(:last_build_failure_notified_at => Time.zone.now)

      BuildFailureNotifier.new(self).post_failure
    end
  end

  def previously_failing?
    !!travis_build_failure_id
  end

  def should_notify_of_failure?
    last_build_failure_notified_at.nil? || last_build_failure_notified_at < 1.day.ago
  end

  # If we have reported a failure before and the branch is now green.
  #
  # The other advantage of checking `last_build_failure_notified_at.nil?` here
  # is that we save a Travis API call, since we shouldn't be creating
  # BuildFailure records without having found a build failure elsewhere (e.g.
  # TravisBranchMonitor).
  #
  # New records will short circut before hitting `Travis::Repository.find`.
  def passing?
    !last_build_failure_notified_at.nil? && Travis::Repository.find(repo.name).branch(name).green?
  end
end
