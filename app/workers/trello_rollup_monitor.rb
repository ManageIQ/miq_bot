require 'trello_helper'

class TrelloRollupMonitor
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  include MiqToolsServices::SidekiqWorkerMixin
  sidekiq_options :queue => :trello_bot, :retry => false

  recurrence { daily.hour_of_day(23) }

  def perform
    if !first_unique_worker?
      logger.info "#{self.class} is already running, skipping"
    else
      process_trello_rollups
    end
  end

  def process_trello_rollups
    # TODO
    # for each rollup
    # find all tags from the team boards in rollup
    # make sure roadmap has an epic card for all tags
    #   - if epic card created for tag, alert board owner where tag came from, 
    #     and use "Unknown Epic" as the Epic Card title
    # make sure each epic card has all team board cards as checklist items
    #   - make sure each epic card checklist item reflects the correct status of
    #     team board card
  end
end
