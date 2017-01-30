module MiqBot
  def self.version
    @version ||= `git describe --tags`.chomp
  end

  def self.current_bot_sha
    @current_git_sha ||= `GIT_DIR=#{Rails.root.join('.git')} git rev-parse --short --verify HEAD`.strip
  end
end
