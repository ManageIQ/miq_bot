class AddStateToBatchJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :batch_jobs, :state, :string
  end
end
