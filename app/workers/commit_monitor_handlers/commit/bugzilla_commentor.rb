class CommitMonitorHandlers::Commit::BugzillaCommentor
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  def self.handled_branch_modes
    [:regular]
  end

  delegate :product, :to => :CommitMonitor

  attr_reader :branch, :commit, :message

  def perform(branch_id, commit, commit_details)
    @branch  = CommitMonitorBranch.where(:id => branch_id).first
    @commit  = commit
    @message = commit_details["message"]

    if @branch.nil?
      logger.info("Branch #{branch_id} no longer exists.  Skipping.")
      return
    end
    if @branch.pull_request?
      logger.info("Branch #{@branch.name} is a pull request.  Skipping.")
      return
    end

    process_commit
  end

  private

  def process_commit
    prefix     = "New commit detected on #{branch.repo.name}/#{branch.name}:"
    commit_uri = branch.commit_uri_to(commit)
    comment    = "#{prefix}\n#{commit_uri}\n\n#{message}"

    MiqToolsServices::Bugzilla.ids_in_git_commit_message(message).each do |bug_id|
      write_to_bugzilla(bug_id, comment)
    end
  end

  def write_to_bugzilla(bug_id, comment)
    log_prefix = "#{self.class.name}##{__method__}"
    logger.info("#{log_prefix} Updating bug id #{bug_id} in Bugzilla.")

    MiqToolsServices::Bugzilla.call do |bz|
      output = ActiveBugzilla::Bug.find(:product => product, :id => bug_id)
      if output.empty?
        logger.error "#{log_prefix} Unable to write for bug id #{bug_id}: Not a '#{product}' bug."
      else
        logger.info "#{log_prefix} Writing to bugzilla for bug id #{bug_id}"
        bug = output.first
        bug.add_comment(comment)
        bug.save
      end
    end
  rescue => err
    logger.error "#{log_prefix} Unable to write for bug id #{bug_id}: #{err}"
  end
end
