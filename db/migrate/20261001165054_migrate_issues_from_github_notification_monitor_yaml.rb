class MigrateIssuesFromGithubNotificationMonitorYaml < ActiveRecord::Migration[7.0]
  YAML_FILE = Rails.root.join("config/github_notification_monitor.yml")

  class Repo < ActiveRecord::Base
  end

  class Issue < ActiveRecord::Base
    belongs_to :repo, :class_name => "MigrateIssuesFromGithubNotificationMonitorYaml::Repo"
  end

  def up
    return if Rails.env.test?
    return unless YAML_FILE.exist?

    data = YAML.load_file(YAML_FILE, :permitted_classes => [Date, Time])
    return if data.blank?

    timestamps = data["timestamps"]
    return if timestamps.blank?

    timestamps.each do |repo_name, issues|
      next if issues.blank?

      repo = Repo.find_by(:name => repo_name)
      next if repo.nil?

      issues.each do |issue_number, last_processed_at|
        next if last_processed_at.blank?

        Issue.find_or_initialize_by(
          :repo_id => repo.id,
          :number  => issue_number
        ).update!(:last_processed_at => last_processed_at)
      end
    end
  end

  def down
    return if Rails.env.test?

    # Repopulate the YAML file from the database so the migration is reversible
    timestamps = {}

    Issue.includes(:repo).where.not(:last_processed_at => nil).each do |issue|
      timestamps[issue.repo.name] ||= {}
      timestamps[issue.repo.name][issue.number] = issue.last_processed_at.utc
    end

    File.write(YAML_FILE, {"timestamps" => timestamps}.to_yaml)
  end
end
