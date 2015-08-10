module TrelloHelper
  module TrelloBugHelper

    def self.included(base)
      base.extend ClassMethods
    end

    BUG_STATUS_TO_TRELLO_LIST = {
      "NEW"      => "New",
      "ASSIGNED" => "Backlog",
      "ON_DEV"   => "In Progress",
      "POST"     => "Complete"
    }

    BUGZILLA_PRODUCT = "Red Hat CloudForms Management Engine"
    BUGZILLA_STATES  = %w(NEW ASSIGNED ON_DEV POST) 
    BUGZILLA_FIELDS  = [:status, :assigned_to, :priority, :summary, :created_on] 
    BUG_PRIORITIES   = %w(unspecified low medium high urgent)

    module ClassMethods
      require 'action_view'
      require 'action_view/helpers'
      include ActionView::Helpers::DateHelper
      #
      # Looks up the bugs for a trello_team's bugzilla_components.
      # Returns a hash of the form:
      #
      #   bugs[BZ_STATUS][BZ_ASSIGNED] => [urgent_bugs, high_bugs, medium_bugs, low_bugs, unspecified_bugs]
      #
      # e.g.,
      #
      #   bugs["NEW"]["assigned@email.com"] => [urgent_bug, high_bug, med_bug, med_bug]
      #
      def bugs_for(trello_team)
        team_name           = trello_team.to_sym
        bugzilla_components = Settings.trello.teams[team_name].bugzilla_components

        bugs = MiqToolsServices::Bugzilla.call do
          ActiveBugzilla::Bug.find(:product        => BUGZILLA_PRODUCT,
                                   :component      => bugzilla_components,
                                   :status         => BUGZILLA_STATES,
                                   :include_fields => BUGZILLA_FIELDS)
        end

        # group bugs by their status and by assigned_to
        group_strategy = Hash.new do |h_status, status|
          h_status[status] = Hash.new do |h_assigned, assigned|
            h_assigned[assigned] = []
          end
        end
        bugs_by_status = bugs.each_with_object(group_strategy) do |bug, hash|
          hash[bug.status][bug.assigned_to] << bug
        end

        # sort the bug lists
        bugs_by_status.each do |_stat, bugs_by_assigned|
          bugs_by_assigned.each do |_assigned, assigned_bugs|
            assigned_bugs.sort! { |a, b| BUG_PRIORITIES.index(b.priority) <=> BUG_PRIORITIES.index(a.priority) }
          end
        end
        bugs_by_status
      end

      def bug_card_for(team, bz_status)
        board_name = Settings.trello.teams[team].board
        list_name  = BUG_STATUS_TO_TRELLO_LIST[bz_status]

        organization.board(board_name).list(list_name).card("Bugs")
      end

      # Any bug checklist items checked in trello should be processed accordingly:
      #
      # - Checked New Bugs: Ignored (bugs have to be manually assigned in Bugzilla)
      # - Checked Backlog Bugs: Move status to ON_DEV
      # - Checked In Progress Bugs: Move status to POST
      # - Checked Complete Bugs: Ignored, no further states to process
      def process_checked_bugs
        bugs_by_status = Hash.new([])

        # find all the "checked" bugs for each status across all the teams
        trello_team_names.each do |team|
          %w(ASSIGNED ON_DEV).each do |bug_status|
            bug_card = bug_card_for(team, bug_status)
            bug_card.checklists.each do |checklist|
              bug_ids = checklist.items.select { |i| i.state == "complete" }.collect { |i| bug_id_from_checklist_item(i) }
              bugs_by_status[bug_status].concat(bug_ids)
            end
          end
        end

        # batch update all the bugs for each status
        bugs_by_status.each do |current_status, bug_ids|
          new_status = case current_status
            when "ASSIGNED"; then "ON_DEV"
            when "ON_DEV";   then "POST"
          end
          MiqToolsServices::Bugzilla.call do |bugzilla|
            bugzilla.service.update(bug_ids, :status => new_status)
          end
        end
      end

      # Looks up the bugs that should be on each bug card and entirely replaces
      # the checklists on those cards with the found bugs.
      #
      def update_bug_checklists
        Settings.trello.teams.each do |team, team_data|
          bugs  = bugs_for(team)
          board = orgnization.board[team_data.board]
          bugs.each do |status, bugs_by_assigned|
            card = bug_card_for(team, status)
            card.remove_all_checklists

            bugs_by_assigned.each do |assigned, assigned_bugs|
              checklist = Trello::Checklist.create(:name => assigned, :board_id => board.id)
              checklist_items = assigned_bugs.collect { |bug| format_bug_checklist_item(bug) }
              checklist.add_items(checklist_items)
            end
          end
        end
      end

      # Returns a formatted string that can be used as a checklist item name for a
      # bug
      def format_bug_checklist_item(bug)
        priority = %w(urgent high).include?(bug.priority) ? "**#{bug.priority}**" : bug.priority
        "[[#{bug.id}] #{bug.summary} (#{priority}) (#{time_ago_in_words(bug.created_on)} old)](#{bz_url(bug)})"
      end

      def bug_id_from_checklist_item(checklist_item)
        checklist_item.name.match(/show_bug\.cgi\?id=([0-9]*)/) { |match| match[1] }
      end

      def bz_url(bug)
        "https://bugzilla.redhat.com/show_bug.cgi?id=#{bug.id}"
      end
    end
  end
end
