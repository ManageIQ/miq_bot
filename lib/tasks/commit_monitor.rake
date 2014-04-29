namespace :commit_monitor do
  task :poll_single => :environment do
    CommitMonitor.perform_async
  end
end
