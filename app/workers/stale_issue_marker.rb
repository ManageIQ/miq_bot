class StaleIssueMarker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot_glacial, :retry => false

  include SidekiqWorkerMixin

  # If an issue/pr has any of these labels, it will not be marked as stale or closed
  PINNED_LABELS       = ['pinned'].freeze
  SEARCH_SORTING      = {:sort => :updated, :direction => :asc}.freeze
  STALE_ISSUE_MESSAGE = <<-EOS.freeze
This issue has been automatically marked as stale because it has not been updated for at least 3 months.

If you can still reproduce this issue on the current release or on `master`, please reply with all of the information you have about it in order to keep the issue open.

Thank you for all your contributions!
  EOS
  CLOSABLE_PR_MESSAGE = <<-EOS.freeze
This pull request has been automatically closed because it has not been updated for at least 3 months.

Feel free to reopen this pull request if these changes are still valid.

Thank you for all your contributions!
  EOS

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
    query  = "is:open archived:false update:<#{stale_date.strftime('%Y-%m-%d')}"
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

    logger.info("[#{Time.now.utc}] - Marking issue #{issue.fq_repo_name}##{issue.number} as stale")
    issue.add_comment(STALE_ISSUE_MESSAGE)
  end

  def comment_and_close(issue)
    mark_as_stale(issue)

    logger.info("[#{Time.now.utc}] - Closing stale PR #{issue.fq_repo_name}##{issue.number}")
    GithubService.close_pull_request(issue.fq_repo_name, issue.number)
    issue.add_comment(CLOSABLE_PR_MESSAGE)
  end
end
