class AddStateToBatchJobs < ActiveRecord::Migration[4.2]
  def change
    add_column :batch_jobs, :state, :string
  end
end
