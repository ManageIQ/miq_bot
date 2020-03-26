class AddOnCompleteClassAndArgsToBatchJobs < ActiveRecord::Migration[4.2]
  def change
    add_column :batch_jobs, :on_complete_class, :string
    add_column :batch_jobs, :on_complete_args, :text
  end
end
