class CreateIssues < ActiveRecord::Migration[7.0]
  def change
    create_table :issues do |t|
      t.references :repo,   :null => false, :foreign_key => true
      t.integer    :number, :null => false
      t.datetime   :last_processed_at
      t.timestamps

      t.index %i[repo_id number], :unique => true
    end
  end
end
