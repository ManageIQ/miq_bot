class AddMergeableToCommitMonitorBranch < ActiveRecord::Migration[4.2]
  def change
    add_column :commit_monitor_branches, :mergeable, :boolean
  end
end
