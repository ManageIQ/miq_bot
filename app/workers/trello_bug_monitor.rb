require 'trello_helper'

class TrelloBugMonitor
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  include MiqToolsServices::SidekiqWorkerMixin
  sidekiq_options :queue => :trello_bot, :retry => false

  recurrence { hourly.minute_of_hour(0, 10, 20, 30, 40, 50) }

  def perform
    if !first_unique_worker?
      logger.info "#{self.class} is already running, skipping"
    else
      process_trello_bugs
    end
  end

  def process_trello_bugs
    TrelloHelper.process_checked_bugs
    TrelloHelper.update_bug_checklist
  end
end
