class TrelloBugMonitor
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  include MiqToolsServices::SidekiqWorkerMixin
  include ActionView::Helpers::DateHelper
  include TrelloHelper
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
    with_trello_service do |trello|
      @trello = trello
      process_checked_bugs
      update_bug_checklists
    end
  end

  private

  BUG_STATUS_TO_TRELLO_LIST = {
    "NEW"      => "New",
    "ASSIGNED" => "Backlog",
    "ON_DEV"   => "In Progress",
    "POST"     => "Complete"
  }

  BUGZILLA_PRODUCT = Settings.commit_monitor.bugzilla_product
  BUGZILLA_STATES  = %w(NEW ASSIGNED ON_DEV POST) 
  BUGZILLA_FIELDS  = [:status, :assigned_to, :priority, :summary, :created_on] 
  BUG_PRIORITIES   = %w(urgent high medium low unspecified)

  attr_reader :trello

  # Any bug checklist items checked in trello should be processed accordingly:
  #
  # - Checked New Bugs: Ignored (bugs have to be manually assigned in Bugzilla)
  # - Checked Backlog Bugs: Move status to ON_DEV
  # - Checked In Progress Bugs: Move status to POST
  # - Checked Complete Bugs: Ignored, no further states to process
  def process_checked_bugs
    checked_bugs_by_status = Hash.new { |h, k| h[k] = [] }

    # find all the "checked" bugs for each status across all the teams
    team_names.each do |team|
      %w(ASSIGNED ON_DEV).each do |bz_status|
        bug_ids = bug_card_for(team, bz_status).checklists.flat_map do |checklist|
          checklist.checked_items.collect(&:bugzilla_id)
        end
        checked_bugs_by_status[bz_status].concat(bug_ids)
      end
    end

    update_checked_bugs(checked_bugs_by_status) 
  end

  def update_checked_bugs(checked_bugs_by_status)
    t = Benchmark.realtime do 
      MiqToolsServices::Bugzilla.call do |bugzilla|
        checked_bugs_by_status.each do |status, bug_ids|
          bugzilla.update(bug_ids, :status => next_bz_status(status))
        end
      end
    end
    logger.debug("Bugzilla Update Time #{t}s")
  end

  def next_bz_status(status)
    case status
    when "ASSIGNED" then "ON_DEV"
    when "ON_DEV"   then "POST"
    end
  end


  # Looks up the bugs that should be on each bug card and entirely replaces
  # the checklists on those cards with the found bugs.
  #
  def update_bug_checklists
    team_names.each do |team|
      bugs_for(team).each do |bz_status, bugs_by_assigned|
        t = Benchmark.realtime do 
          card = bug_card_for(team, bz_status)
          card.remove_all_checklists

          bugs_by_assigned.each do |assigned, assigned_bugs|
            items = assigned_bugs.collect { |bug| format_checklist_item_from(bug) }
            card.create_checklist(assigned, items)
          end
        end
        logger.debug("Updated Trello Team #{team}/#{bz_status} #{t}s")
      end
    end
  end

  def bug_card_for(team, bz_status)
    board_name = team_settings(team).board
    list_name  = BUG_STATUS_TO_TRELLO_LIST[bz_status]

    trello.board(board_name).list(list_name).card("Bugs")
  end

  def format_bug_priority(bug)
    case bug.priority
    when "urgent", "high" then ":red_circle: **#{bug.priority}**"
    when "medium"         then ":large_orange_diamond: #{bug.priority}"
    else                       ":small_blue_diamond: #{bug.priority}"
    end
  end

  # Returns a formatted string that can be used as a checklist item name for a
  # bug
  def format_checklist_item_from(bug)
    priority = format_bug_priority(bug)
    title    = bug.id
    text     = "#{priority} (#{time_ago_in_words(bug.created_on)} old) #{bug.summary}" 
    url      = MiqToolsServices::Bugzilla.url_for(bug.id)
    "[[#{title}](#{url})] #{text}"
  end

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
  def bugs_for(team)
    bugzilla_components = team_settings(team).bugzilla_components

    bugs = nil
    t = Benchmark.realtime do
      bugs = MiqToolsServices::Bugzilla.call do
        ActiveBugzilla::Bug.find(:product        => BUGZILLA_PRODUCT,
                                 :component      => bugzilla_components,
                                 :status         => BUGZILLA_STATES,
                                 :include_fields => BUGZILLA_FIELDS)
      end
    end
    logger.debug("Bugzilla Query Time: #{t}s")

    # group bugs by their status and by assigned_to
    bugs_by_status = Hash.new do |h_status, status|
      h_status[status] = Hash.new do |h_assigned, assigned|
        h_assigned[assigned] = []
      end
    end
    bugs.each_with_object(bugs_by_status) do |bug, hash|
      hash[bug.status][bug.assigned_to] << bug
    end

    # sort the bug lists
    bugs_by_status.each do |_stat, bugs_by_assigned|
      bugs_by_assigned.each do |_assigned, assigned_bugs|
        assigned_bugs.sort_by! { |bug| BUG_PRIORITIES.index(bug.priority) }
      end
    end

    bugs_by_status
  end
end
