class Repo < ActiveRecord::Base
  BASE_PATH = Rails.root.join("repos")

  has_many :branches, :dependent => :destroy

  validates :name, :presence => true, :uniqueness => true

  def self.create_from_github!(name, url)
    create_and_clone!(name, url).tap(&:ensure_prs_refs)
  end

  def self.create_and_clone!(name, url)
    path = BASE_PATH.join(name)

    raise ArgumentError, "a git repo already exists at #{path}" if path.join(".git").exist?

    MinigitService.clone(url, path)
    last_commit = MinigitService.call(path, &:current_ref)

    create!(:name => name).tap do |repo|
      repo.branches.create!(
        :name        => "master",
        :last_commit => last_commit
      )
    end
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

  def can_have_prs?
    # TODO: Need a better check for repos that *can* have PRs
    !!upstream_user
  end

  def ensure_prs_refs
    MinigitService.call(path, &:ensure_prs_refs) if can_have_prs?
  end

  def with_git_service
    raise "no block given" unless block_given?
    MinigitService.call(path) do |git|
      git.fetch("--all")
      yield git
    end
  end

  def with_travis_service
    raise "no block given" unless block_given?

    Travis.github_auth(Settings.github_credentials.password)
    yield Travis::Repository.find(name)
  end

  def enabled_for?(checker)
    Array(Settings.public_send(checker).enabled_repos).each_with_object([]) { |value, values|
      values << (value.kind_of?(Array) ? value.first.to_s : value)
    }.include?(name)
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

  # @param expected [Array<Hash>] The desired state of the PR branches.
  #   Caller should pass an Array of Hashes that contain the PR's number,
  #   pr_title, html_url, and merge_target.
  def synchronize_pr_branches(expected)
    raise "repo cannot not have PR branches" unless can_have_prs?

    git_fetch # TODO: Let's get rid of this!

    results = Hash.new { |h, k| h[k] = [] }

    transaction do
      existing = pr_branches.index_by(&:pr_number)

      expected.each do |e|
        number   = e.delete(:number)
        html_url = e.delete(:html_url)
        e.merge!(
          :name         => MinigitService.pr_branch(number),
          :commit_uri   => File.join(html_url, "commit", "$commit"),
          :pull_request => true
        )

        branch = existing.delete(number)

        if branch
          # Update
          branch.attributes = e
          key = branch.changed? ? :updated : :unchanged
        else
          # Add
          branch = branches.build(e)
          branch.last_commit = branch.git_service.merge_base
          key = :added
        end

        branch.save!
        results[key] << branch
      end

      # Delete
      deleted = existing.values
      branches.destroy(deleted)
      results[:deleted] = deleted
    end

    results
  end

  # TODO: Move this to GitService::Repo
  def git_fetch
    require 'rugged'
    rugged_repo = Rugged::Repository.new(path.to_s)
    rugged_repo.remotes.each do |remote|
      fetch_options = {}

      username = extract_username_from_git_remote_url(remote.url)
      fetch_options[:credentials] = Rugged::Credentials::SshKeyFromAgent.new(:username => username) if username

      rugged_repo.fetch(remote.name, fetch_options)
    end
  end

  def create_branch!(branch_name)
    b = branches.new(:name => branch_name)

    # Make sure the branch is a real git branch before continuing and saving a record
    raise(ActiveRecord::RecordInvalid, "Branch not found in git") unless b.git_service.send(:rugged_repo).branches.exists?("origin/#{b.name}")

    b.last_commit = b.git_service.merge_base("master")

    b.save!
  end

  private

  def extract_username_from_git_remote_url(url)
    url.start_with?("http") ? nil : url.match(/^.+?(?=@)/).to_s.presence
  end
end
