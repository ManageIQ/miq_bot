class CollapseRepoUpstreamUserIntoName < ActiveRecord::Migration[5.1]
  class Repo < ActiveRecord::Base
  end

  def up
    say_with_time("Collapse Repo upstream_user into name") do
      Repo.all.each do |r|
        r.update_attributes!(:name => [r.upstream_user, r.name].compact.join("/"))
      end
    end

    remove_column :repos, :upstream_user
  end

  def down
    add_column :repos, :upstream_user, :string

    say_with_time("Split out Repo upstream_user from name") do
      Repo.all.each do |r|
        r.update_attributes!(:upstream_user => name_parts(r.name).first, :name => name_parts(r.name).last)
      end
    end
  end

  def name_parts(name)
    name.split("/", 2).unshift(nil).last(2)
  end
end
