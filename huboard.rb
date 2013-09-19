include GitHubApi

class Huboard 
  attr_accessor :huboard_labels

  def self.get_labels(repo)
    @huboard_labels = []
    labels = repo.labels
    labels.each do |l|
      if l.match(/^\d+ -/)
        @huboard_labels << l
      end
    end
    @huboard_labels.sort!
    return @huboard_labels #TODO: reevaluate when the array has > 10 elements
  end

  def self.valid_state?(state_id)
    state_id >= 0 && !@huboard_labels[state_id].nil?
  end

  def self.get_label_text(state_id)
    @huboard_labels[state_id]
  end
end