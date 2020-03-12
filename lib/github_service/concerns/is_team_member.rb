module IsTeamMember
  def triage_member?(username)
    IsTeamMember.triage_team_members.include?(username)
  end

  # List of usernames for the traige team
  #
  # Cache triage_team_members, and refresh cache every 24 hours
  #
  # Note:  This is created as a class method
  #
  cache_with_timeout(:triage_team_members, 24 * 60 * 60) do
    if member_organization_name && triage_team_name
      team = GithubService.org_teams(member_organization_name)
                          .detect { |t| t.name == triage_team_name }

      if team.nil?
        []
      else
        GithubService.team_members(team.id).map(&:login)
      end
    else
      []
    end
  end

  module_function

  def triage_team_name
    @triage_team_name ||= Settings.triage_team_name || nil
  end

  def member_organization_name
    @member_organization_name ||= Settings.member_organization_name || nil
  end
end
