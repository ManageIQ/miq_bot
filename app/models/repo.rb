class Repo < ActiveRecord::Base
  has_many :branches, :dependent => :destroy

  validates :name, :presence => true, :uniqueness => true
  validates :path, :presence => true, :uniqueness => true

  def self.create_from_github!(name, path)
    MiqToolsServices::MiniGit.call(path) do |git|
      git.checkout("master")
      git.pull

      repo = self.create!(
        :name => name,
        :path => path
      )

      repo.branches.create!(
        :name        => "master",
        :commit_uri  => Branch.github_commit_uri(name),
        :last_commit => git.current_ref
      )

      repo
    end
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

  def path=(val)
    super(File.expand_path(val))
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
