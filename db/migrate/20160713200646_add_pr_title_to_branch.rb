class AddPrTitleToBranch < ActiveRecord::Migration[5.1]
  def change
    add_column :branches, :pr_title, :string
  end
end
