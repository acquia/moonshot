# frozen_string_literal: true

module Moonshot
  module RotateAsgInstances
    class SSHValidationError < StandardError
      def initialize(response)
        super("SSH failed. exit status: #{response.exitstatus} " \
              "output: #{response.output} error: #{response.error}")
      end
    end

    class SSH
      # As per the standard it is raising correctly but still giving an error.
      def test_ssh_connection(instance_id)
        Retriable.retriable(base_interval: 5, tries: 3) do
          response = exec('/bin/true', instance_id)
          # rubocop:disable Style/RaiseArgs
          raise SSHValidationError.new(response) unless
            response.exitstatus.zero?
          # rubocop:enable Style/RaiseArgs
        end
      end

      def exec(command, instance_id)
        fe = SSHForkExecutor.new
        fe.run(build_command(command, instance_id))
      end

      private

      def build_command(command, instance_id)
        cb = SSHCommandBuilder.new(Moonshot.config.ssh_config, instance_id)
        cb.build(command).cmd
      end
    end
  end
end
