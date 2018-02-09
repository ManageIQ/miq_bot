class CommitMonitorHandlers::BugzillaCommenter
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot

  include BranchWorkerMixin

  def self.handled_branch_modes
    [:regular]
  end

  attr_reader :commit, :message

  def perform(branch_id, new_commits)
    return unless find_branch(branch_id, :regular)

    bugs = Hash.new { |h, k| h[k] = [] }

    new_commits.each do |commit|
      message = repo.git_service.commit(commit).full_message
      BugzillaService.search_in_message(message).each do |bug|
        bugs[bug[:bug_id]] << bug.merge(:commit => commit, :commit_message => message)
      end
    end

    bugs.each do |bug_id, info|
      resolved = info.any? { |i| i[:resolution] }
      comment_parts = info.collect { |i| format_comment_part(i[:commit], i[:commit_message]) }
      comments = build_comments(comment_parts)

      update_bugzilla_status(bug_id, comments, resolved)
    end
  end

  private

  def update_bugzilla_status(bug_id, comments, resolution)
    logger.info "Adding #{"comment".pluralize(comments.size)} to bug #{bug_id}."

    BugzillaService.call do |service|
      service.with_bug(bug_id) do |bug|
        break if bug.nil?

        comments.each { |comment| bug.add_comment(comment) }
        update_bug_status(bug) if resolution
        bug.save
      end
    end
  end

  def message_header(messages)
    @message_header ||= "New #{"commit".pluralize(messages.size)} detected on #{fq_repo_name}/#{branch.name}:\n\n"
  end

  def build_comments(messages)
    message_builder = BugzillaService::MessageBuilder.new(message_header(messages))
    messages.each { |m| message_builder.write("#{m}\n\n\n") }
    message_builder.comments
  end

  def format_comment_part(commit, message)
    "#{branch.commit_uri_to(commit)}\n#{message}"
  end

  def update_bug_status(bug)
    case bug.status
    when "NEW", "ASSIGNED", "ON_DEV"
      logger.info "Changing status of bug #{bug.id} to POST."
      bug.status = "POST"
    else
      logger.info "Not changing status of bug #{bug.id} due to status of #{bug.status}"
    end
  end
end
