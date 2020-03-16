class AddMergeableToCommitMonitorBranch < ActiveRecord::Migration[5.1]
  def change
    add_column :commit_monitor_branches, :mergeable, :boolean
  end
end
