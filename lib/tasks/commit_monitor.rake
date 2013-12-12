namespace :commit_monitor do
  desc "Run polling loop for the commit monitor"
  task :poll => :environment do
    loop do
      CommitMonitorWorker.perform_async
      sleep(60)
    end
  end

  task :poll_single => :environment do
    CommitMonitorWorker.perform_async
  end
end
