require 'thor'

module Moonshot
  # A SSHCommand that is automatically registered with the
  # Moonshot::CommandLine, including options for SSH access.
  class SSHCommand < Moonshot::Command
    def parser
      parser = super
      parser.on('-l', '--user USER', 'User to log into remote machine as') do |v|
        Moonshot.config.ssh_config.ssh_user = v
      end

      parser.on('-i', '--identity-file FILE', 'SSH Private Key to authenticate with') do |v|
        Moonshot.config.ssh_config.ssh_identity_file = v
      end

      parser.on('-s', '--instance INSTANCE_ID', 'Specific AWS EC2 ID to connect to') do |v|
        Moonshot.config.ssh_instance = v
      end

      parser.on('-c', '--command COMMAND', 'Command to execute on the remote host') do |v|
        Moonshot.config.ssh_command = v
      end

      parser.on('-g', '--auto-scaling-group ASG_NAME',
                'The logical ID of the ASG to SSH into, required for multiple stacks') do |v|
        Moonshot.config.ssh_auto_scaling_group_name = v
      end
    end
  end
end
