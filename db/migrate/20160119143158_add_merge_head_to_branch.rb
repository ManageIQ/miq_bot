class AddMergeHeadToBranch < ActiveRecord::Migration[5.1]
  class Branch < ActiveRecord::Base; end

  def up
    add_column :branches, :merge_target, :string

    Branch.update_all(:merge_target => "master")
  end

  def down
    remove_column :branches, :merge_target
  end
end
