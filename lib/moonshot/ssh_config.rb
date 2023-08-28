# frozen_string_literal: true

module Moonshot
  class SSHConfig
    attr_accessor :ssh_identity_file, :ssh_user, :ssh_options

    def initialize
      @ssh_identity_file = ENV['MOONSHOT_SSH_KEY_FILE']
      @ssh_user = ENV['MOONSHOT_SSH_USER']
      @ssh_options = ENV['MOONSHOT_SSH_OPTIONS']
    end
  end
end
