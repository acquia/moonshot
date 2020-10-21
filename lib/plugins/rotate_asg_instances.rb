# frozen_string_literal: true

require 'aws-sdk'

module Moonshot
  module Plugins
    # Rotate ASG instances after update.
    class RotateAsgInstances
      include DoctorHelper

      def doctor(resources)
        @resources = resources
        run_all_checks
      end

      def pre_update(resources)
        @resources = resources
        asg.verify_ssh
      end

      def post_update(resources)
        @resources = resources
        asg.perform_rotation
      end

      private

      def asg
        Moonshot::RotateAsgInstances::ASG.new(@resources)
      end

      def doctor_check_ssh
        asg.verify_ssh
        success('Successfully opened SSH connection to an instance.')
      rescue Moonshot::RotateAsgInstances::SSHValidationError
        critical('SSH connection test failed, check your SSH settings')
      end
    end
  end
end
