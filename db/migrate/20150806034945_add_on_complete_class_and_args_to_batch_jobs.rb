class AddOnCompleteClassAndArgsToBatchJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :batch_jobs, :on_complete_class, :string
    add_column :batch_jobs, :on_complete_args, :text
  end
end
