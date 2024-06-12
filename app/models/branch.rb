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

  def self.create_all_from_master(name)
    Repo.all.each do |repo|
      next if repo.branches.exists?(:name => name)

      b = repo.branches.new(:name => name)
      next unless b.git_service.exists?

      b.last_commit = b.git_service.merge_base("master")
      b.save!
      puts "Created #{name} on #{repo.name}"
    end
  end

  def self.with_branch_or_pr_number(n)
    n = MinigitService.pr_branch(n) if n.kind_of?(Integer)
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
    pr_title.to_s.match(/^(?:\s*\[[\w-]+\])+/).to_s.gsub("[", " [").split.map { |s| s[1...-1] }
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
end
