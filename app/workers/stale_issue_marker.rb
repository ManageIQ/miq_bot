class StaleIssueMarker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot_glacial, :retry => false

  include SidekiqWorkerMixin

  SEARCH_SORTING = {:sort => :updated, :direction => :asc}.freeze

  def perform
    if !first_unique_worker?
      logger.info("#{self.class} is already running, skipping")
    else
      process_stale_issues
    end
  end

  private

  # If an issue/pr has any of these labels, it will not be marked as stale or closed
  def pinned_labels
    Array(settings.pinned_labels || ["pinned"])
  end

  # Triage logic:
  #
  # After 3 month of no activity:
  #   - add stale tag (if it is no there)
  #   - add comment
  #
  def process_stale_issues
    handle_newly_stale_issues
  end

  def handle_newly_stale_issues
    query  = "is:open archived:false updated:<#{stale_date.strftime('%Y-%m-%d')}"
    query << " " << enabled_repos_query_filter
    query << " " << unpinned_query_filter

    GithubService.search_issues(query, **SEARCH_SORTING).each do |issue|
      comment_as_stale(issue)
    end
  end

  def stale_date
    @stale_date ||= 3.months.ago
  end

  def stale_label
    GithubService::Issue::STALE_LABEL
  end

  def enabled_repos_query_filter
    enabled_repo_names.map { |repo| %(repo:"#{repo}") }.join(" ")
  end

  def unpinned_query_filter
    pinned_labels.map { |label| %(-label:"#{label}") }.join(" ")
  end

  def validate_repo_has_stale_label(repo)
    unless GithubService.valid_label?(repo, stale_label)
      raise "The label #{stale_label} does not exist on #{repo}"
    end
  end

  def mark_as_stale(issue)
    return if issue.stale?

    validate_repo_has_stale_label(issue.fq_repo_name)
    issue.add_labels([stale_label])
  end

  def comment_as_stale(issue)
    mark_as_stale(issue)

    message = "This #{issue.type} has been automatically marked as stale " \
              "because it has not been updated for at least 3 months.\n\n"
    message <<
      if issue.pull_request?
        "If these changes are still valid, please remove the "    \
          "`stale` label, make any changes requested by reviewers " \
          "(if any), and ensure that this issue is being looked "   \
          "at by the assigned/reviewer(s)."
      else
        "If you can still reproduce this issue on the current " \
          "release or on `master`, please reply with all of the " \
          "information you have about it in order to keep the "   \
          "issue open."
      end

    logger.info("[#{Time.now.utc}] - Marking issue #{issue.fq_repo_name}##{issue.number} as stale")
    issue.add_comment(message)
  end
end
