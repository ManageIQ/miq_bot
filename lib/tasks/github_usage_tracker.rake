namespace :github_usage_tracker do
  desc "Record a current datapoint of GitHub API usage"
  task :record_datapoint => :environment do
    GithubUsageTracker.record_datapoint
  end
end
