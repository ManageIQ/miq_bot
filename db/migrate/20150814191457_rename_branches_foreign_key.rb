class RenameBranchesForeignKey < ActiveRecord::Migration[4.2]
  def change
    rename_column :branches, :commit_monitor_repo_id, :repo_id
  end
end
