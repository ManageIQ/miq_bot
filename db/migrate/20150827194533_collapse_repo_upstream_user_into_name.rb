class CollapseRepoUpstreamUserIntoName < ActiveRecord::Migration
  class Repo < ActiveRecord::Base
  end

  def up
    say_with_time("Collapse Repo upstream_user into name") do
      Repo.all.each do |r|
        r.update_attributes!(:name => "#{r.upstream_user}/#{r.name}")
      end
    end

    remove_column :repos, :upstream_user
  end

  def down
    add_column :repos, :upstream_user, :string

    say_with_time("Split out Repo upstream_user from name") do
      Repo.all.each do |r|
        r.update_attributes!(:upstream_user => r.name.split("/").first, :name => r.name.split("/").last)
      end
    end
  end
end
