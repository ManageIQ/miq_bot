class RenameCommitMonitorReposToRepos < ActiveRecord::Migration
  def change
    rename_table :commit_monitor_repos, :repos
  end
end
