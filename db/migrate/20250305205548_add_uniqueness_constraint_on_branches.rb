class AddUniquenessConstraintOnBranches < ActiveRecord::Migration[6.1]
  def up
    add_index(:branches, [:name, :repo_id], unique: true)
  end
end
