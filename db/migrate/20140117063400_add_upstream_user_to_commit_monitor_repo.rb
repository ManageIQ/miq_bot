class AddUpstreamUserToCommitMonitorRepo < ActiveRecord::Migration[5.1]
  def change
    add_column :commit_monitor_repos, :upstream_user, :string
  end
end
