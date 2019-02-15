class CreateCommitMonitorRepos < ActiveRecord::Migration[5.1]
  def change
    create_table :commit_monitor_repos do |t|
      t.string :name
      t.string :path
      t.timestamps
    end
  end
end
