# frozen_string_literal: true

module Moonshot
  # Create and execute SSM commands using AWS SDK
  class SSMCommandBuilder
    Result = Struct.new(:cmd, :instance_id)

    def initialize(ssm_config, instance_id)
      @config = ssm_config
      @instance_id = instance_id
    end

    def build(command = nil)
      # For SSM, we don't build a shell command string
      # Instead we return the command and instance_id for SDK execution
      Result.new(command, @instance_id)
    end
  end
end
