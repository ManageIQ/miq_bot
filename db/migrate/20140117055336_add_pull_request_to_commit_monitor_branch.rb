class AddPullRequestToCommitMonitorBranch < ActiveRecord::Migration
  def change
    add_column :commit_monitor_branches, :pull_request, :boolean
  end
end
