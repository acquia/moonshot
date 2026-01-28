# frozen_string_literal: true

require 'aws-sdk-ssm'

module Moonshot
  # Execute commands on EC2 instances using AWS Systems Manager
  class SSMForkExecutor
    Result = Struct.new(:output, :exitstatus)

    def initialize
      @ssm_client = Aws::SSM::Client.new
    end

    def run(command, instance_id)
      # Send command using SSM
      response = @ssm_client.send_command(
        instance_ids: [instance_id],
        document_name: 'AWS-RunShellScript',
        parameters: {
          'commands' => [command]
        },
        timeout_seconds: 600
      )

      command_id = response.command.command_id

      # Wait for command to complete and get output
      wait_for_command_completion(command_id, instance_id)

      # Get command output
      output_response = @ssm_client.get_command_invocation(
        command_id: command_id,
        instance_id: instance_id
      )

      Result.new(
        output_response.standard_output_content.to_s.chomp,
        map_status_to_exit_code(output_response.status, output_response.response_code)
      )
    rescue Aws::SSM::Errors::ServiceError => e
      Result.new("SSM Error: #{e.message}", 1)
    end

    private

    def wait_for_command_completion(command_id, instance_id, max_attempts = 60)
      attempts = 0
      loop do
        invocation = @ssm_client.get_command_invocation(
          command_id: command_id,
          instance_id: instance_id
        )

        status = invocation.status
        return invocation if %w[Success Failed Cancelled TimedOut].include?(status)

        attempts += 1
        raise "Command timed out after #{max_attempts} attempts" if attempts >= max_attempts

        sleep 1
      end
    end

    def map_status_to_exit_code(status, response_code)
      return response_code if response_code && response_code != -1

      case status
      when 'Success'
        0
      when 'Failed', 'Cancelled', 'TimedOut'
        1
      else
        1
      end
    end
  end
end
