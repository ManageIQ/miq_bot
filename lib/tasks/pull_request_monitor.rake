namespace :pull_request_monitor do
  desc "Run polling loop for the pull request monitor"
  task :poll => :environment do
    loop do
      print "."
      PullRequestMonitor.perform_async
      sleep(60)
    end
  end

  task :poll_single => :environment do
    PullRequestMonitor.perform_async
  end
end
