class PullRequestMonitor
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot_glacial, :retry => false

  include SidekiqWorkerMixin

  def self.enabled_repos
    super.includes(:branches).select(&:can_have_prs?)
  end

  def self.handlers
    @handlers ||= begin
      workers_path = Rails.root.join("app/workers")
      Dir.glob(workers_path.join("pull_request_monitor_handlers/*.rb")).collect do |f|
        path = Pathname.new(f).relative_path_from(workers_path).to_s
        path.chomp(".rb").classify.constantize
      end
    end
  end

  def self.handlers_for(repo)
    handlers.select { |h| h.enabled_for?(repo) }
  end

  def perform
    if !first_unique_worker?
      logger.info("#{self.class} is already running, skipping")
    else
      process_repos
    end
  end

  def process_repos
    enabled_repos.each do |repo|
      process_repo(repo)
      Thread.pass # Allow Sidekiq to do other work (see https://github.com/sidekiq/sidekiq/discussions/5039)
    end
  end

  def process_repo(repo)
    return unless repo.can_have_prs?

    results = repo.synchronize_pr_branches(github_prs(repo))

    branches = results[:updated] + results[:added]
    branches.product(self.class.handlers_for(repo)) { |b, h| h.perform_async(b.id) }
  end

  private

  def github_prs(repo)
    GithubService.pull_requests(repo.name).map do |github_pr|
      {
        :number       => github_pr.number,
        :html_url     => github_pr.head.repo.try(:html_url) || github_pr.base.repo.html_url,
        :merge_target => github_pr.base.ref,
        :pr_title     => github_pr.title
      }
    end
  end
end
