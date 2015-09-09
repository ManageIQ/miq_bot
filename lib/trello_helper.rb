module TrelloHelper
  def team_names
    Settings.trello.teams.keys
  end

  def team_settings(name)
    Settings.trello.teams[name]
  end

  def with_trello_service
    MiqToolsServices::Trello.call(Settings.trello.organization_id) do |trello|
      yield trello
    end
  end
end
