class CommitMonitorHandlers::Commit::GemfileChecker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

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

    @commit = commit
    process_branch
  end

  private

  def tag
    "<gemfile_checker />"
  end

  def process_branch
    send("process_#{branch.pull_request? ? "pr" : "regular"}_branch")
  end

  def process_pr_branch
    @pr = branch.pr_number
    logger.info("#{self.class.name}##{__method__} Updating pull request #{pr} with Gemfile comment.")

    branch.repo.with_github_service do |github|
      @github = github
      delete_pr_comments(pr_gemfile_comments)
      add_pr_gemfile_comment
    end
  end

  def github_org_repo
    [branch.repo.upstream_user, branch.repo.name]
  end
  def delete_pr_comments(comments)
    ids = comments.collect(&:id)
    return if ids.empty?

    logger.info("#{self.class.name}##{__method__} PR: #{pr}, Deleting comments: #{ids.inspect}")
    github.delete_issue_comments(ids)
  end

  def add_pr_gemfile_comment
    logger.info("#{self.class.name}##{__method__} PR: #{pr} Adding Gemfile comment")
    github.issues.comments.create(
      :issue_id => pr,
      :body     => "#{tag}#{Settings.gemfile_checker.pr_contacts.join(" ")} Gemfile changes detected in commit #{branch.commit_uri_to(commit)}.  Please review."
    )
  end

  def pr_gemfile_comments
    github.select_issue_comments(pr) do |comment|
      gemfile_comment?(comment)
    end
  end

  def gemfile_comment?(comment)
    comment.body.start_with?(tag)
  end

  def process_regular_branch
    # TODO: Support regular branches with EmailService once we can send email.
  end
end
