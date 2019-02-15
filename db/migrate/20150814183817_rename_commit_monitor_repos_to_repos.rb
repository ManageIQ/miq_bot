class RenameCommitMonitorReposToRepos < ActiveRecord::Migration[5.1]
  def change
    rename_table :commit_monitor_repos, :repos
  end
end
