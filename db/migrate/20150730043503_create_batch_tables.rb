class CreateBatchTables < ActiveRecord::Migration[5.1]
  def change
    create_table :batch_jobs do |t|
      t.timestamps
      t.timestamp :expires_at
    end

    create_table :batch_entries do |t|
      t.belongs_to :batch_job
      t.index      :batch_job_id

      t.string :state
      t.text   :result
    end
  end
end
