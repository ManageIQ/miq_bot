module GitService
  class Credentials
    # Example:
    #
    #   GitService::Credentials.host_config = {
    #     '*' => {
    #       :username    => 'git',
    #       :private_key => '~/.ssh/id_rsa'
    #     },
    #     'github.com' => {
    #       :username    => 'git',
    #       :private_key => '~/.ssh/id_rsa'
    #     }
    #   }
    #
    def self.host_config=(host_config = {})
      @host_config = host_config.to_h
    end

    # Generic method for finding git credentials based on what is available
    #
    # Will use ssh_agent if all other options have been exhausted.
    #
    def self.find_for_user_and_host(username, hostname)
      from_ssh_config(username, hostname) || from_ssh_agent(username)
    end

    def self.from_ssh_config(username, hostname)
      ssh_config = Net::SSH::Config.for(hostname)

      return if ssh_config.empty? || ssh_config[:keys].nil?

      ssh_config[:username]   = username || ssh_config[:user]             # favor URL username if present
      ssh_config[:privatekey] = File.expand_path(ssh_config[:keys].first) # only use first key

      Rugged::Credentials::SshKey.new(ssh_config)
    end

    def self.from_ssh_agent(username)
      Rugged::Credentials::SshKeyFromAgent.new(:username => username)
    end
  end
end
