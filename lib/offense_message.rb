class OffenseMessage
  attr_accessor :entries

  def initialize
    @entries = []
  end

  def lines
    entries.sort.group_by(&:group).collect do |group, sub_entries|
      [
        format_group(group),
        sub_entries.collect(&:to_s),
        ""
      ]
    end.flatten.compact[0...-1]
  end

  private

  def format_group(group)
    "**#{group}**" if group
  end
end
