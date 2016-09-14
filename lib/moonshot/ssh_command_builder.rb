require 'shellwords'

module Moonshot
  # Create an ssh command from configuration.
  class SSHCommandBuilder
    Result = Struct.new(:cmd, :ip)

    def initialize(ssh_config, instance_id)
      @config = ssh_config
      @instance_id = instance_id
    end

    def build(command = nil)
      cmd = ['ssh', '-t']
      cmd << "-i #{@config.ssh_identity_file}" if @config.ssh_identity_file
      cmd << "-l #{@config.ssh_user}" if @config.ssh_user
      cmd << instance_ip
      cmd << Shellwords.escape(command) if command
      Result.new(cmd.join(' '), instance_ip)
    end

    private

    def instance_ip
      @instance_ip ||= Aws::EC2::Client.new
                                       .describe_instances(instance_ids: [@instance_id])
                                       .reservations.first.instances.first.public_ip_address
    rescue
      raise "Failed to determine public IP address for instance #{@instance_id}!"
    end
  end
end
