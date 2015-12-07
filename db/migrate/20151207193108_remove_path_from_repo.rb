class RemovePathFromRepo < ActiveRecord::Migration
  def change
    remove_column :repos, :path, :string
  end
end
