class UpdateBranchNameForPrBranches < ActiveRecord::Migration[4.2]
  class Branch < ActiveRecord::Base; end # Don't use the real model

  def up
    Branch.where(:pull_request => true).each do |branch|
      pr_number = branch.name.split("/").last
      branch.update_attributes(:name => "prs/#{pr_number}/head")
    end
  end

  def down
    Branch.where(:pull_request => true).each do |branch|
      pr_number = branch.name.split("/")[1]
      branch.update_attributes(:name => "pr/#{pr_number}")
    end
  end
end
