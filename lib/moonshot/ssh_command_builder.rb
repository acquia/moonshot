# frozen_string_literal: true

require 'shellwords'

module Moonshot
  # Create a tsh ssh command from configuration.
  class SSHCommandBuilder
    Result = Struct.new(:cmd, :host)

    def initialize(ssh_config, instance_id, teleport_config)
      @config          = ssh_config
      @instance_id     = instance_id
      @teleport_config = teleport_config
    end

    def build(command = nil)
      cmd = ['tsh', 'ssh']
      cmd << @config.ssh_options if @config.ssh_options
      cmd << "--proxy=#{@teleport_config.proxy_url}"
      cmd << "-ti #{@teleport_config.identity_file}" if @teleport_config.bot_user?
      cmd << '-tA'
      cmd << "#{@teleport_config.ssh_user}@#{instance_host}"
      cmd << Shellwords.escape(command) if command
      Result.new(cmd.join(' '), instance_host)
    end

    private

    def instance_host
      @instance_host ||= @teleport_config.host_for(@instance_id)
    end
  end
end
