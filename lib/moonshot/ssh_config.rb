# frozen_string_literal: true

module Moonshot
  class SSHConfig
    attr_accessor :ssh_identity_file, :ssh_user

    def initialize
      @ssh_identity_file = ENV.fetch('MOONSHOT_SSH_KEY_FILE', nil)
      @ssh_user = ENV.fetch('MOONSHOT_SSH_USER', nil)
    end
  end
end
