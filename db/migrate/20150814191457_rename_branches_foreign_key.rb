class RenameBranchesForeignKey < ActiveRecord::Migration
  def change
    rename_column :branches, :commit_monitor_repo_id, :repo_id
  end
end
