class AddLinterOffenseCountToBranch < ActiveRecord::Migration[5.1]
  def change
    add_column :branches, :linter_offense_count, :integer
  end
end
