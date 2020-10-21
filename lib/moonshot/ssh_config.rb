module Moonshot
  class SSHConfig
    attr_accessor :ssh_identity_file
    attr_accessor :ssh_user
    attr_accessor :ssh_options

    def initialize
      @ssh_identity_file = ENV['MOONSHOT_SSH_KEY_FILE']
      @ssh_user = ENV['MOONSHOT_SSH_USER']
      @ssh_options = ENV['MOONSHOT_SSH_OPTIONS']
    end
  end
end
