class PullRequestMonitor
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  include MiqToolsServices::SidekiqWorkerMixin
  sidekiq_options :queue => :miq_bot_glacial, :retry => false

  recurrence { hourly.minute_of_hour(0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55) }

  def perform
    if !first_unique_worker?
      logger.info "#{self.class} is already running, skipping"
    else
      process_repos
    end
  end

  def process_repos
    Repo.includes(:branches).each { |repo| process_repo(repo) }
  end

  def process_repo(repo)
    return unless repo.can_have_prs?

    repo.synchronize_pr_branches(github_prs(repo))
  end

  private

  def github_prs(repo)
    repo.with_github_service do |github|
      github.pull_requests.all.collect do |github_pr|
        {
          :number       => github_pr.number,
          :html_url     => github_pr.head.repo.try(:html_url) || github_pr.base.repo.html_url,
          :merge_target => github_pr.base.ref,
          :pr_title     => github_pr.title
        }
      end
    end
  end
end
