class AddMergeableToCommitMonitorBranch < ActiveRecord::Migration
  def change
    add_column :commit_monitor_branches, :mergeable, :boolean
  end
end
