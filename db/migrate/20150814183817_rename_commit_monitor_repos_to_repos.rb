class RenameCommitMonitorReposToRepos < ActiveRecord::Migration[4.2]
  def change
    rename_table :commit_monitor_repos, :repos
  end
end
