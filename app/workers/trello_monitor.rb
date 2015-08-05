require 'trello_helper'

class TrelloMonitor
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  include MiqToolsServices::SidekiqWorkerMixin
  sidekiq_options :queue => :trello_bot, :retry => false

  recurrence { hourly.minute_of_hour(0, 10, 20, 30, 40, 50) }

  def perform
    if !first_unique_worker?
      logger.info "#{self.class} is already running, skipping"
    else
      process_trello_boards
    end
  end

  def process_trello_boards
    process_bugs
    process_roadmaps
  end

  def process_bugs
    TrelloHelper.process_checked_bugs
    TrelloHelper.update_bug_checklist
  end

  def process_roadmaps
    # TODO
    # find all tags from team boards
    # make sure roadmap has an epic card for all tags
    #   - if epic card created for tag, alert board owner where tag came from
    # make sure each epic card has all team board cards as checklist items
    #   - make sure each epic card checklist item reflects the correct status of
    #     team board card
  end
end
