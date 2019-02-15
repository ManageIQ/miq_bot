class RenameCommitMonitorBranchesToBranches < ActiveRecord::Migration[5.1]
  def change
    rename_table :commit_monitor_branches, :branches
  end
end
