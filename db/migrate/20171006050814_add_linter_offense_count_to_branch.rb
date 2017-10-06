class AddLinterOffenseCountToBranch < ActiveRecord::Migration
  def change
    add_column :branches, :linter_offense_count, :integer
  end
end
