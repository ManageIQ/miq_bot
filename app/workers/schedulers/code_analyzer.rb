module Schedulers
  class CodeAnalyzer
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot_glacial, :retry => false

    include Sidetiq::Schedulable
    recurrence { daily }

    include SidekiqWorkerMixin

    def perform
      Repo.where(:name => fq_repo_names).each do |repo|
        repo.branches.pluck(:id).each do |branch_id|
          CommitMonitorHandlers::Branch::CodeAnalyzer.perform_async(branch_id)
        end
      end
    end

    private

    def fq_repo_names
      Settings.code_analyzer.enabled_repos
    end
  end
end
