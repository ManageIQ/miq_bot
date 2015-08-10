module TrelloHelper
  module TrelloRollupHelper

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      EPIC_ROLLUP_LISTS = %w(In\ Progress Next Backlog New Complete)
      EPIC_BACKLOG_LIST = "Epic Backlog"

      def process_rollups
        Settings.trello.rollups.each do |rollup|
          # error out unless respond_to? rollup.type.to_sym
          send(rollup.type) if respond_to? rollup.type.to_sym
        end
      end

      def epic_tag_rollup(rollup)
        epic_cards = gather_epic_card_details(rollup)
        replace_epic_cards(rollup.board, epic_cards)
      end

      def replace_epic_cards(board_name, epic_cards)
        epic_board = organization.board(board_name)
        list       = epic_board.list(EPIC_BACKLOG_LIST)

        epic_cards.each do |epic_name, lists|
          card = find_or_create_epic_card(list, epic_name)
          card.remove_all_checklists

          lists.each do |list_name, checklist_items| 
            cl = card.create_new_checklist(list_name)
            checklist_items.each do |item|
              completed = list_name == "Complete"
              cl.add_item(item, completed)
            end
          end
        end  
      end

      # {epic_name => {list_name => ["card name (board name)", "card name (board name)"]}}
      def gather_epic_card_details(rollup)
        team_boards = rollup.teams.collect do |team|
          TrelloHelper.organization.board(Settings.trello.teams[team].board)
        end

        grouper = Hash.new do |h_epic, epic_name| 
          h_epic[epic_name] = Hash.new { |h_list, list_name| h_list[list_name] = [] }
        end
        team_boards.each_with_object(grouper) do |board, hash|
          EPIC_ROLLUP_LISTS.each do |list_name|
            list = board.list(list_name)
            list.cards.each do |card|
              epic_name = parse_epic_from_card(card.name)
              list_name = card.list.name
              hash[epic_name][list_name] << format_epic_checklist_item(card)
            end
          end
        end
      end

      # Returns the epic name for a card name.
      # Card names have the format:
      #   "(Sizing:number) [Epic name] card title"
      # Some examples with return values: 
      # * "(1) [Epic name] card title" => "Epic name"
      # * "(3)Card title" => nil
      # * "(1)[Epic name] card [title]" => "Epic name"
      def parse_epic_from_card(card_name) 
        card_name.match(/^\([0-9]*\)\s*\[(.*?)\]/) { |match| match[1] }
      end

      def format_epic_checklist_item(card)
        "[#{card.name}](#{card.short_url}) (#{card.board.name})"
      end

      def find_or_create_epic_card(list, epic_name)
        card = list.cards.select { |c| c.name.include? "[#{epic_name}]" }
        card ||= list.add_card("[#{epic_name}] Unknown Epic!")
      end
    end
  end
end
