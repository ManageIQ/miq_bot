class AddPullRequestToCommitMonitorBranch < ActiveRecord::Migration[5.1]
  def change
    add_column :commit_monitor_branches, :pull_request, :boolean
  end
end
