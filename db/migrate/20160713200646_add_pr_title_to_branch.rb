class AddPrTitleToBranch < ActiveRecord::Migration
  def change
    add_column :branches, :pr_title, :string
  end
end
