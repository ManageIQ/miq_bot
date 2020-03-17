class RenameCommitMonitorBranchesToBranches < ActiveRecord::Migration[4.2]
  def change
    rename_table :commit_monitor_branches, :branches
  end
end
