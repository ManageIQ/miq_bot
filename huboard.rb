class Huboard 

  @labels = [
    "0 - To Do",
    "1 - Analyze: Doing",
    "2 - Analyze: Done",
    "3 - Dev: Doing",
    "4 - Dev: Done",
    "5 - Test",
    "6 - Accept: Ready",
    "7 - Accept: Done"
  ]
  
  def self.get_labels
    return @labels
  end

  def self.valid_state?(state_id)
    if @labels[state_id].nil? || state_id < 0
      return false
    else
      return true
    end
  end

  def self.get_label_text(state_id)
    return @labels[state_id]
  end
end