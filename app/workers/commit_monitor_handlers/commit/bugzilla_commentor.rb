class CommitMonitorHandlers::Commit::BugzillaCommentor
  include Sidekiq::Worker

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
      logger.info("Branch #{@branch_id} no longer exists.  Skipping.")
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

    message.each_line do |line|
      match = %r{^\s*https://bugzilla\.redhat\.com/show_bug\.cgi\?id=(?<bug_id>\d+)$}.match(line)
      write_to_bugzilla(match[:bug_id], comment) if match
    end
  end

  def write_to_bugzilla(bug_id, comment)
    log_prefix = "#{self.class.name}##{__method__}"
    logger.info("#{log_prefix} Updating bug id #{bug_id} in Bugzilla.")

    BugzillaService.call do |bz|
      output = bz.query(:product => product, :bug_id => bug_id).chomp
      if output.empty?
        logger.error "#{log_prefix} Unable to write for bug id #{bug_id}: Not a '#{product}' bug."
      else
        logger.info "#{log_prefix} Writing to bugzilla for bug id #{bug_id}"
        bz.modify(bug_id, :comment => comment)
      end
    end
  rescue => err
    logger.error "#{log_prefix} Unable to write for bug id #{bug_id}: #{err}"
  end
end
