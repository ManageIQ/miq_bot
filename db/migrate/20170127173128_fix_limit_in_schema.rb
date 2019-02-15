class FixLimitInSchema < ActiveRecord::Migration[5.1]
  def up
    change_column :batch_entries, :state, :string, :limit => 255
    change_column :batch_jobs, :on_complete_class, :string, :limit => 255
    change_column :batch_jobs, :state, :string, :limit => 255
    change_column :branches, :name, :string, :limit => 255
    change_column :branches, :commit_uri, :string, :limit => 255
    change_column :branches, :last_commit, :string, :limit => 255
    change_column :repos, :name, :string, :limit => 255
  end

  def down
    change_column :batch_entries, :state, :string, :limit => nil
    change_column :batch_jobs, :on_complete_class, :string, :limit => nil
    change_column :batch_jobs, :state, :string, :limit => nil
    change_column :branches, :name, :string, :limit => nil
    change_column :branches, :commit_uri, :string, :limit => nil
    change_column :branches, :last_commit, :string, :limit => nil
    change_column :repos, :name, :string, :limit => nil
  end
end
