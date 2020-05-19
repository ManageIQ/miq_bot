module GitService
  class Credentials
    # Generic method for finding git credentials based on what is available
    #
    # Will use ssh_agent if all other options have been exhausted.
    #
    def self.find_for_user_and_host(username, hostname)
      from_ssh_agent(username)
    end

    def self.from_ssh_agent(username)
      Rugged::Credentials::SshKeyFromAgent.new(:username => username)
    end
  end
end
