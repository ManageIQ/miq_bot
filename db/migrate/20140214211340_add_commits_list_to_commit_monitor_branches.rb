class AddCommitsListToCommitMonitorBranches < ActiveRecord::Migration[4.2]
  def change
    add_column :commit_monitor_branches, :commits_list, :text
  end
end
