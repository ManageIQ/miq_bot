namespace :data do
  desc "Backup the Repos and branches to a YAML file"
  task :backup => :environment do
    data = CommitMonitorRepo.all.collect do |repo|
      branches = repo.branches.all.collect do |branch|
        {
          "name"            => branch.name,
          "commit_uri"      => branch.commit_uri,
          "last_commit"     => branch.last_commit,
          "last_checked_on" => branch.last_checked_on,
          "last_changed_on" => branch.last_changed_on,
          "pull_request"    => branch.pull_request,
          "commits_list"    => branch.commits_list,
          "mergeable"       => branch.mergeable
        }
      end

      {
        "name"          => repo.name,
        "path"          => repo.path,
        "upstream_user" => repo.upstream_user,
        "branches"      => branches
      }
    end
    path = Rails.root.join("config", "data_backup")
    File.write(path, YAML.dump(data))
  end

  desc "Restore the Repos and branches from a YAML file"
  task :restore => :environment do
    path = Rails.root.join("config", "data_backup")
    data = YAML.load(File.read(path))

    data.each do |repo|
      ar_repo = CommitMonitorRepo.create!(
        :name          => repo["name"],
        :path          => repo["path"],
        :upstream_user => repo["upstream_user"],
      )

      repo["branches"].each do |branch|
        CommitMonitorBranch.create!(
          :name            => branch["name"],
          :commit_uri      => branch["commit_uri"],
          :last_commit     => branch["last_commit"],
          :last_checked_on => branch["last_checked_on"],
          :last_changed_on => branch["last_changed_on"],
          :pull_request    => branch["pull_request"],
          :commits_list    => branch["commits_list"],
          :mergeable       => branch["mergeable"],
          :repo            => ar_repo,
        )
      end
    end
  end
end
