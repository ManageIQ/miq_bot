namespace :commit_monitor do
  desc "Run polling loop for the commit monitor"
  task :poll => :environment do
    loop do
      print "."
      CommitMonitor.perform_async
      sleep(CommitMonitor.options["poll"])
    end
  end

  task :poll_single => :environment do
    CommitMonitor.perform_async
  end
end
