class CreateCommitMonitorRepos < ActiveRecord::Migration[4.2]
  def change
    create_table :commit_monitor_repos do |t|
      t.string :name
      t.string :path
      t.timestamps
    end
  end
end
