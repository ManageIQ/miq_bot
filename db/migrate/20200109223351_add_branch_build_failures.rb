class AddBranchBuildFailures < ActiveRecord::Migration[5.2]
  def change
    add_column :branches, :travis_build_failure_id, :integer
    add_column :branches, :last_build_failure_notified_at, :datetime
  end
end
