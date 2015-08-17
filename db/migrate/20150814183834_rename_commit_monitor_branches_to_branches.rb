class RenameCommitMonitorBranchesToBranches < ActiveRecord::Migration
  def change
    rename_table :commit_monitor_branches, :branches
  end
end
