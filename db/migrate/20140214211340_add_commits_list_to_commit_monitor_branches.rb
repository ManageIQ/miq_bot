class AddCommitsListToCommitMonitorBranches < ActiveRecord::Migration
  def change
    add_column :commit_monitor_branches, :commits_list, :text
  end
end
