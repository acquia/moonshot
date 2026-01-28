# frozen_string_literal: true

require 'moonshot/ssh_fork_executor'
require 'moonshot/ssm_fork_executor'

module Moonshot
  module Tools
    class ASGRollout
      # This object is passed into hooks defined in the ASGRollout
      # process, to give them access to instances and logging
      # facilities.
      class HookExecEnvironment
        attr_reader :instance_id

        def initialize(config, instance_id)
          @ilog = config.interactive_logger
          @config = config
          @instance_id = instance_id

          # Determine connection method (default to SSM)
          @connection_method = config.respond_to?(:connection_method) ? config.connection_method : :ssm

          @command_builder = if @connection_method == :ssm
                               Moonshot::SSMCommandBuilder.new(config.ssm_config, instance_id)
                             else
                               Moonshot::SSHCommandBuilder.new(config.ssh_config, instance_id)
                             end
        end

        def exec(cmd)
          cb = @command_builder.build(cmd)

          if @connection_method == :ssm
            debug("Executing via SSM on #{@instance_id}: #{cmd}")
            fe = SSMForkExecutor.new
            fe.run(cb.cmd, cb.instance_id)
          else
            debug("Executing via SSH on #{@instance_id}: #{cmd}")
            fe = SSHForkExecutor.new
            fe.run(cb.cmd)
          end
        end

        def ec2
          Aws::EC2::Client.new
        end

        def ec2_instance
          res = Aws::EC2::Resource.new(client: ec2)
          res.instance(@instance_id)
        end

        def debug(msg)
          @ilog.debug(msg)
        end

        def info(msg)
          @ilog.info(msg)
        end
      end
    end
  end
end
