class AddPrTitleToBranch < ActiveRecord::Migration[4.2]
  def change
    add_column :branches, :pr_title, :string
  end
end
