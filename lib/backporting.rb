module Backporting
  TARGET_BRANCHES = %w(darga euwe).freeze

  # Backport requests are merged pull requests from the ManageIQ repos marked by
  # labels such as 'darga/yes'
  def self.search_for_backport_requests(branch)
    GithubService.search_issues("user:ManageIQ is:merged label:#{branch}/yes",
                                   :sort  => "updated",
                                   :order => "desc").items
  end
end
