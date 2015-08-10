require 'trello'
require 'active_bugzilla'
require_relative 'bot/rails_config_settings'

# Some ruby-trello monkey-patching
# Allow boards, lists, cards, and checklists to be looked up by name
module Trello
  class Organization
    def board(name)
      @board_hash ||= boards.each_with_object({}) { |board, hash| hash[board.name] = board }
      @board_hash[name]
    end
  end

  class Board
    def list(name)
      @list_hash ||= lists.each_with_object({}) { |list, hash| hash[list.name] = list }
      @list_hash[name]
    end
  end

  class List
    def card(name)
      @card_hash ||= cards.each_with_object({}) { |card, hash| hash[card.name] = card }
      @card_hash[name]
    end

    def add_card(card_name)
      Trello::Card.create(:name => card_name, :list_id => self.id, :pos => "bottom")
    end
  end

  class Card
    def checklist(name)
      @checklist_hash ||= checklists.each_with_object({}) { |checklist, hash| hash[checklist.name] = checklist }
      @checklist_hash[name]
    end

    # create_new_checklist should return the new checklist object and not the post body from the API response
    alias_method :old_create_new_checklist, :create_new_checklist
    # Create and return a new checklist for this card
    def create_new_checklist(checklist_name)
      old_create_new_checklist(checklist_name)
      checklist(checklist_name)
    end

    def remove_all_checklists
      checklists.each(&:delete)
    end
  end

  class Checklist
    # Adds an array of strings as unchecked items
    def add_items(checklist_items)
      checklist_items.each { |i| add_item(i) }
    end
  end
end

require_relative 'trello_helper/trello_bug_helper'
require_relative 'trello_helper/trello_rollup_helper'

module TrelloHelper
  include TrelloHelper::TrelloBugHelper
  include TrelloHelper::TrelloRollupHelper

  # Trello OAuth Configuration
  #Trello.configure do |config|
    #config.consumer_key       = Settings.trello.oauth.consumer_key,
    #config.consumer_secret    = Settings.trello.oauth.consumer_secret,
    #config.oauth_token        = Settings.trello.oauth.oauth_token,
    #config.oauth_token_secret = Settings.trello.oauth.oauth_token_secret
  #end

  # Trello Basic Auth Configuration
  Trello.configure do |config|
    config.developer_public_key = Settings.trello.basic_auth.developer_key
    config.member_token         = Settings.trello.basic_auth.member_token
  end

  class << self
    def trello_team_names
      @trello_team_names ||= Settings.trello.teams.keys
    end

    def organization
      @organization ||= Trello::Organization.find(Settings.trello.organization_id)
    end
  end
end
