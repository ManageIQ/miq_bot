module ApplicationHelper
  def time_ago_in_words_with_nil_check(time)
    time.nil? ? "Never" : "#{time_ago_in_words(time).capitalize} ago"
  end
end
