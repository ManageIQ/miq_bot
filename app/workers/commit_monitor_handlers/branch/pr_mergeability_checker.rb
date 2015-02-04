class CommitMonitorHandlers::Branch::PrMergeabilityChecker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  def self.handled_branch_modes
    [:pr]
  end

  attr_reader :branch

  def perform(branch_id)
    @branch = CommitMonitorBranch.where(:id => branch_id).first

    if @branch.nil?
      logger.info("Branch #{branch_id} no longer exists.  Skipping.")
      return
    end
    unless @branch.pull_request?
      logger.info("Branch #{@branch.name} is not a pull request.  Skipping.")
      return
    end

    process_mergeability
  end

  private

  def tag
    "<pr_mergeability_checker />"
  end

  def process_mergeability
    was_mergeable = branch.mergeable?
    currently_mergeable = branch.repo.with_git_service do |git|
      git.mergeable?(branch.name, "master")
    end

    write_to_github if was_mergeable && !currently_mergeable

    # Update columns directly to avoid collisions wrt the serialized column issue
    branch.update_columns(:mergeable => currently_mergeable)
  end

  def write_to_github
    logger.info("#{self.class.name}##{__method__} Updating pull request #{branch.pr_number} with merge issue.")

    branch.repo.with_github_service do |github|
      github.issues.comments.create(
        :issue_id => branch.pr_number,
        :body     => "#{tag}This pull request is not mergeable.  Please rebase and repush."
      )
    end
  end
end
