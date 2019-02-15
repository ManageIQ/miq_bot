class RemovePathFromRepo < ActiveRecord::Migration[5.1]
  def change
    remove_column :repos, :path, :string
  end
end
