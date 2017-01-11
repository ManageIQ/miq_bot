module MiqBot
  def self.version
    @version ||= `git describe --tags`.chomp
  end
end
