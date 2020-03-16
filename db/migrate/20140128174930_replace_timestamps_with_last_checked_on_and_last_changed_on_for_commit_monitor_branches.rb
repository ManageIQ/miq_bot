class ReplaceTimestampsWithLastCheckedOnAndLastChangedOnForCommitMonitorBranches < ActiveRecord::Migration[5.1]
  class CommitMonitorBranch < ActiveRecord::Base
  end

  def change
    add_column :commit_monitor_branches, :last_checked_on, :timestamp
    add_column :commit_monitor_branches, :last_changed_on, :timestamp

    say_with_time("Moving commit_monitor_branches.updated_at to commit_monitor_branches.last_changed_on") do
      CommitMonitorBranch.all.each do |b|
        b.update_attributes!(:last_changed_on => b.updated_at)
      end
    end

    remove_column :commit_monitor_branches, :created_at, :timestamp
    remove_column :commit_monitor_branches, :updated_at, :timestamp
  end
end
