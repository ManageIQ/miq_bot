class AddUpstreamUserToCommitMonitorRepo < ActiveRecord::Migration
  def change
    add_column :commit_monitor_repos, :upstream_user, :string
  end
end
