class AddUpstreamUserToCommitMonitorRepo < ActiveRecord::Migration[4.2]
  def change
    add_column :commit_monitor_repos, :upstream_user, :string
  end
end
