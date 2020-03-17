class RemovePathFromRepo < ActiveRecord::Migration[4.2]
  def change
    remove_column :repos, :path, :string
  end
end
