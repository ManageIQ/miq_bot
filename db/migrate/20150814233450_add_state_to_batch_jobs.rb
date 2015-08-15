class AddStateToBatchJobs < ActiveRecord::Migration
  def change
    add_column :batch_jobs, :state, :string
  end
end
