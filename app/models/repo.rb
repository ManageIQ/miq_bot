class Repo < ActiveRecord::Base
  BASE_PATH = Rails.root.join("repos")

  has_many :branches, :dependent => :destroy

  validates :name, :presence => true, :uniqueness => true

  after_destroy :remove_git_clone
  after_update  :move_git_clone

  def self.create_from_github!(name, url)
    create_and_clone!(name, url).tap(&:ensure_prs_refs)
  end

  def self.create_and_clone!(name, url)
    path = BASE_PATH.join(name)

    raise ArgumentError, "a git repo already exists at #{path}" if path.join(".git").exist?

    MinigitService.clone(url, path)

    create!(:name => name).tap do |repo|
      repo.create_branch!("master")
    end
  end

  def self.path(name)
    BASE_PATH.join(name)
  end

  def self.org_path(name)
    parent = path(name).parent
    parent == BASE_PATH ? nil : parent
  end

  def path
    self.class.path(name)
  end

  def org_path
    self.class.org_path(name)
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

  def branch_names
    branches.pluck(:name)
  end

  def regular_branches
    branches.regular_branches
  end

  def regular_branch_names
    regular_branches.pluck(:name)
  end

  def pr_branches
    branches.pr_branches
  end

  def pr_branch_names
    pr_branches.pluck(:name)
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

  def git_fetch
    git_service.git_fetch
  end

  def create_branch!(branch_name)
    b = branches.new(:name => branch_name)

    # Make sure the branch is a real git branch before continuing and saving a record
    unless b.git_service.exists?
      b.errors.add(:name, "of branch not found in git")
      raise ActiveRecord::RecordInvalid.new(b) # rubocop:disable Style/RaiseArgs
    end

    b.last_commit = b.git_service.merge_base("master")

    b.save!
  end

  def git_service
    GitService::Repo.new(self)
  end

  private

  def extract_username_from_git_remote_url(url)
    url.start_with?("http") ? nil : url.match(/^.+?(?=@)/).to_s.presence
  end

  def move_git_clone
    return unless saved_change_to_name?

    path_was = self.class.path(previous_changes[:name].first)
    return unless path_was.exist?

    org_path&.mkpath
    FileUtils.mv(path_was, path)

    org_path_was = self.class.org_path(previous_changes[:name].first)
    org_path_was.rmtree if org_path_was&.empty? # rubocop:disable Lint/SafeNavigationWithEmpty
  end

  def remove_git_clone
    path.rmtree
    org_path.rmtree if org_path&.empty? # rubocop:disable Lint/SafeNavigationWithEmpty
  rescue Errno::ENOENT
  end
end
