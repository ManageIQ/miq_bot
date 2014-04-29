namespace :pull_request_monitor do
  task :poll_single => :environment do
    PullRequestMonitor.perform_async
  end
end
