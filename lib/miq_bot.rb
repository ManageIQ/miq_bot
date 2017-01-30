module MiqBot
  def self.version
    @version ||= `GIT_DIR=#{Rails.root.join('.git')} git describe --tags`.chomp
  end
end
