module ApplicationHelper
  def application_version
    MiqBot.version
  end

  def time_ago_in_words_with_nil_check(time)
    time.nil? ? "Never" : "#{time_ago_in_words(time).capitalize} ago"
  end

  def grafana_url
    Settings.grafana.url
  end
end
