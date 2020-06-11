class StaleIssueMarker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot_glacial, :retry => false

  include SidekiqWorkerMixin

  # If an issue/pr has any of these labels, it will not be marked as stale or closed
  PINNED_LABELS  = ['pinned'].freeze
  SEARCH_SORTING = {:sort => :updated, :direction => :asc}.freeze
  COMMENT_FOOTER = <<~FOOTER.sub("ManageIQ\n", "ManageIQ ").strip!
    Thank you for all your contributions!  More information about the ManageIQ
    triage process can be found in [the triage process documentation][1].

    [1]: https://www.manageiq.org/docs/guides/triage_process
  FOOTER

  # Triage logic:
  #
  # - Stale after 3 month of no activity
  # - Close after stale and inactive for 3 more months
  # - Stale and unmergeable should be closed (assume abandoned, can still be re-opened)
  #
  def perform
    handle_newly_stale_issues
    handle_stale_and_unmergable_prs
  end

  private

  def handle_newly_stale_issues
    query  = "is:open archived:false updated:<#{stale_date.strftime('%Y-%m-%d')}"
    query << enabled_repos_query_filter
    query << unpinned_query_filter

    GithubService.search_issues(query, SEARCH_SORTING).each do |issue|
      if issue.stale? || issue.unmergeable?
        comment_and_close(issue)
      else
        comment_as_stale(issue)
      end
    end
  end

  def handle_stale_and_unmergable_prs
    query  = "is:open archived:false is:pr"
    query << %( label:"#{stale_label}" label:"#{unmergeable_label}")
    query << enabled_repos_query_filter
    query << unpinned_query_filter

    GithubService.search_issues(query, SEARCH_SORTING).each { |issue| comment_and_close(issue) }
  end

  def stale_date
    @stale_date ||= 3.months.ago
  end

  def stale_label
    GithubService::Issue::STALE_LABEL
  end

  def unmergeable_label
    GithubService::Issue::UNMERGEABLE_LABEL
  end

  def enabled_repos_query_filter
    " #{enabled_repo_names.map { |repo| %(repo:"#{repo}") }.join(" ")}"
  end

  def unpinned_query_filter
    " #{PINNED_LABELS.map { |label| %(-label:"#{label}") }.join(" ")}"
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
    if issue.pull_request?
      message << "If these changes are still valid, please remove the "    \
                 "`stale` label, make any changes requested by reviewers " \
                 "(if any), and ensure that this issue is being looked "   \
                 "at by the assigned/reviewer(s)\n\n"
    else
      message << "If you can still reproduce this issue on the current " \
                 "release or on `master`, please reply with all of the " \
                 "information you have about it in order to keep the "   \
                 "issue open.\n\n"
    end
    message << COMMENT_FOOTER

    logger.info("[#{Time.now.utc}] - Marking issue #{issue.fq_repo_name}##{issue.number} as stale")
    issue.add_comment(message)
  end

  def comment_and_close(issue)
    mark_as_stale(issue)

    message  = "This #{issue.type} has been automatically closed because it " \
               "has not been updated for at least 3 months.\n\n"
    message << "Feel free to reopen this #{issue.type} if "
    message << "these changes are still valid.\n\n" if issue.pull_request?
    message << "this issue is still valid.\n\n"     unless issue.pull_request?
    message << COMMENT_FOOTER

    logger.info("[#{Time.now.utc}] - Closing stale #{issue.type} #{issue.fq_repo_name}##{issue.number}")
    GithubService.close_issue(issue.fq_repo_name, issue.number)
    issue.add_comment(message)
  end
end
