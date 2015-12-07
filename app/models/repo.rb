class Repo < ActiveRecord::Base
  BASE_PATH = Rails.root.join("repos")

  has_many :branches, :dependent => :destroy

  validates :name, :presence => true, :uniqueness => true

  def self.create_from_github!(name, url)
    create_and_clone!(name, url, Branch.github_commit_uri(name))
  end

  def self.create_and_clone!(name, url, commit_uri)
    path = BASE_PATH.join(name)

    raise ArgumentError, "a git repo already exists at #{path}" if path.join(".git").exist?

    MiqToolsServices::MiniGit.clone(url, path)
    last_commit = MiqToolsServices::MiniGit.call(path, &:current_ref)

    create!(
      :name     => name,
      :branches => Branch.new(
        :name        => "master",
        :commit_uri  => commit_uri,
        :last_commit => last_commit
      )
    )
  end

  def path
    BASE_PATH.join(name)
  end

  def name_parts
    name.split("/", 2).unshift(nil).last(2)
  end

  def upstream_user
    name_parts.first
  end

  def project
    name_parts.last
  end

  def with_git_service
    raise "no block given" unless block_given?
    MiqToolsServices::MiniGit.call(path) { |git| yield git }
  end

  def with_github_service
    raise "no block given" unless block_given?
    MiqToolsServices::Github.call(:user => upstream_user, :repo => project) { |github| yield github }
  end

  def with_travis_service
    raise "no block given" unless block_given?

    Travis.github_auth(Settings.github_credentials.password)
    yield Travis::Repository.find(name)
  end

  def enabled_for?(checker)
    Array(Settings.public_send(checker).enabled_repos).include?(name)
  end

  def branch_names
    branches.collect(&:name)
  end

  def pr_branches
    branches.select(&:pull_request?)
  end

  def pr_branch_names
    pr_branches.collect(&:name)
  end

  def stale_pr_branches
    pr_branch_names - github_branch_names
  end

  private

  def github_branch_names
    with_github_service do |github|
      github.pull_requests.all.collect do |pr|
        MiqToolsServices::MiniGit.pr_branch(pr.number)
      end
    end
  end
end
