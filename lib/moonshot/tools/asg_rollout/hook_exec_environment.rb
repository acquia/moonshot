require 'moonshot/ssh_fork_executor'

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
          @command_builder = Moonshot::SSHCommandBuilder.new(config.ssh_config, instance_id)
          @instance_id = instance_id
        end

        def exec(cmd)
          cb = @command_builder.build(cmd)
          fe = SSHForkExecutor.new
          fe.run(cb.cmd)
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
