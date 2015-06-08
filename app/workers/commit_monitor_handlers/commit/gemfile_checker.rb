class CommitMonitorHandlers::Commit::GemfileChecker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  LABEL_NAME = "gem changes".freeze

  def self.handled_branch_modes
    [:pr]
  end

  attr_reader :branch, :commit, :github, :pr

  def perform(branch_id, commit, commit_details)
    @branch = CommitMonitorBranch.find(branch_id)

    if @branch.nil?
      logger.info("Branch #{branch_id} no longer exists.  Skipping.")
      return
    end

    enabled_repos = Settings.gemfile_checker.enabled_repos
    unless @branch.repo.fq_name.in?(enabled_repos)
      logger.info("#{self.class} only runs in #{enabled_repos}, not #{@branch.repo.fq_name}.  Skipping.")
      return
    end

    return unless commit_details["files"].any? { |f| File.basename(f) == "Gemfile" }

    @pr     = @branch.pr_number
    @commit = commit
    process_branch
  end

  private

  def tag
    "<gemfile_checker />"
  end

  def gemfile_comment
    "#{tag}#{Settings.gemfile_checker.pr_contacts.join(" ")} Gemfile changes detected in commit #{branch.commit_uri_to(commit)}.  Please review."
  end

  def process_branch
    send("process_#{branch.pull_request? ? "pr" : "regular"}_branch")
  end

  def process_pr_branch
    logger.info("#{self.class.name}##{__method__} Updating pull request #{pr} with Gemfile comment.")

    branch.repo.with_github_service do |github|
      @github = github
      replace_gemfile_comments
      add_pr_label
    end
  end

  def replace_gemfile_comments
    github.replace_issue_comments(pr, gemfile_comment) do |old_comment|
      gemfile_comment?(old_comment)
    end
  end

  def add_pr_label
    add_issue_label(pr, LABEL_NAME)
  end

  def gemfile_comment?(comment)
    comment.body.start_with?(tag)
  end

  def process_regular_branch
    # TODO: Support regular branches with EmailService once we can send email.
  end

  def github_org_repo
    [branch.repo.upstream_user, branch.repo.name]
  end

  #TODO: this should be extracted as a bot interface to the github_api
  def get_issue(number)
    github.issues.get(*github_org_repo, number)
  end

  def get_issue_labels(number)
    get_issue(number).labels.collect(&:name)
  end

  def issue_has_label?(number, label)
    issue_labels = get_issue_labels(number)
    logger.debug("#{self.class.name}##{__method__} PR: #{number}, Prior labels: #{issue_labels}")
    issue_labels.include?(label)
  end

  def add_issue_label(number, label)
    return if issue_has_label?(number, label)

    logger.info("#{self.class.name}##{__method__} Issue #{number}, Adding label: #{label.inspect}")
    github.issues.labels.add(*github_org_repo, number, label)
  end
end
