module Schedulers
  class CodeAnalyzer
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot_glacial, :retry => false

    include Sidetiq::Schedulable
    recurrence { daily }

    include SidekiqWorkerMixin

    def perform
      enabled_repos.each do |repo|
        repo.branches.regular_branches.pluck(:id).each do |branch_id|
          ::CodeAnalyzer.perform_async(branch_id)
        end
      end
    end
  end
end
