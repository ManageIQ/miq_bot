class CommitMonitorHandlers::Commit::GemfileChecker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  def self.handled_branch_modes
    [:pr]
  end

  attr_reader :branch, :commit

  def perform(branch_id, commit, commit_details)
    @branch = CommitMonitorBranch.find(branch_id)

    if @branch.nil?
      logger.info("Branch #{branch_id} no longer exists.  Skipping.")
      return
    end
    if @branch.repo.fq_name != "ManageIQ/manageiq"
      logger.info("#{self.class} only runs on ManageIQ/manageiq, not #{@branch.repo.fq_name}.  Skipping.")
      return
    end

    return unless commit_details["files"].any? { |f| File.basename(f) == "Gemfile" }

    @commit = commit
    process_branch
  end

  private

  def process_branch
    send("process_#{branch.pull_request? ? "pr" : "regular"}_branch")
  end

  def process_pr_branch
    logger.info("#{self.class.name}##{__method__} Updating pull request #{branch.pr_number} with Gemfile comment.")

    branch.repo.with_github_service do |github|
      github.issues.comments.create(
        :issue_id => branch.pr_number,
        :body     => "#{Settings.gemfile_checker.pr_contacts.join(" ")} Gemfile changes detected in commit #{branch.commit_uri_to(commit)}.  Please review."
      )
    end
  end

  def process_regular_branch
    # TODO: Support regular branches with EmailService once we can send email.
  end
end
