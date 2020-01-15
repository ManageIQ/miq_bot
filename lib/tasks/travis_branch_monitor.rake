namespace :travis_branch_monitor do
  task :poll_single => :environment do
    TravisBranchMonitor.new.perform
  end
end
