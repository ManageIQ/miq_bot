class AddPullRequestToCommitMonitorBranch < ActiveRecord::Migration[4.2]
  def change
    add_column :commit_monitor_branches, :pull_request, :boolean
  end
end
