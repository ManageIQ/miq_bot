class AddCommitsListToCommitMonitorBranches < ActiveRecord::Migration[5.1]
  def change
    add_column :commit_monitor_branches, :commits_list, :text
  end
end
