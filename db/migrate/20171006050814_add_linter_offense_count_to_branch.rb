class AddLinterOffenseCountToBranch < ActiveRecord::Migration[4.2]
  def change
    add_column :branches, :linter_offense_count, :integer
  end
end
