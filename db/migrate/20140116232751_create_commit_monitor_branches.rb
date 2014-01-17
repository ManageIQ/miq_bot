class CreateCommitMonitorBranches < ActiveRecord::Migration
  def change
    create_table :commit_monitor_branches do |t|
      t.string :name
      t.string :commit_uri
      t.string :last_commit
      t.belongs_to :commit_monitor_repo
      t.timestamps
    end
  end
end
