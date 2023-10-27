# frozen_string_literal: true

module Moonshot
  module RotateAsgInstances
    class ASG # rubocop:disable Metrics/ClassLength
      include Moonshot::CredsHelper

      def initialize(resources)
        @resources = resources
        @ssh = Moonshot::RotateAsgInstances::SSH.new
        @ilog = @resources.ilog
      end

      def perform_rotation
        teardown_outdated_instances if rotate_asg_instances
      end

      def verify_ssh
        @ssh.test_ssh_connection(first_instance_id)
      end

      private

      def asg
        @asg ||=
          Aws::AutoScaling::AutoScalingGroup.new(name: physical_resource_id)
      end

      def first_instance_id
        SSHTargetSelector.new(
          @resources.controller.stack,
          asg_name: Moonshot.config.ssh_auto_scaling_group_name
        ).choose!
      end

      def rotate_asg_instances
        @ilog.start_threaded('Rotating ASG instances...') do |step|
          @step = step
          outdated = identify_outdated_instances
          if outdated.empty?
            @step.success('No outdated instances to rotate.')
            false
          else
            with_scale_up do
              @volumes_to_delete = outdated_volumes(outdated)
              @shutdown_instances = cycle_instances(outdated)
            end
            @step.success('ASG instances rotated successfully!')
            true
          end
        end
      end

      def teardown_outdated_instances
        @ilog.start_threaded('Tearing down outdated instances...') do |step|
          @step = step
          terminate_instances(@shutdown_instances)
          reap_volumes(@volumes_to_delete)
          @step.success('Outdated instances removed successfully!')
        end
      end

      def identify_outdated_instances
        asg.instances.reject do |i|
          i.launch_configuration_name == asg.launch_configuration_name
        end
      end

      def with_scale_up
        scaled_up = scale_up_if_possible
        yield
      rescue StandardError => e
        @ilog.error("Failure encountered during scale up to the desired capacity: #{e.message}")
      ensure
        # We avoid raising an error in ensure since that can lead to losing the error from the
        # above block.
        attempt_scale_down if scaled_up
      end

      def physical_resource_id
        @resources.controller.stack
                  .resources_of_type('AWS::AutoScaling::AutoScalingGroup')
                  .first.physical_resource_id
      end

      # Scales up the asg by incrementing the desired count by 1. This is to
      # make sure that the desired number of instances is maintained even while
      # they are rotated one at a time.
      def scale_up_if_possible
        desired_capacity = asg.desired_capacity
        if desired_capacity < asg.max_size
          scale_asg(desired_capacity + 1)
          true
        else
          false
        end
      end

      def attempt_scale_down
        scale_asg(asg.reload.desired_capacity - 1)
      rescue StandardError => e
        @ilog.error("Failure encountered during scale down of the desired capacity after rotation: #{e.message}")
      end

      def outdated_volumes(outdated_instances)
        volumes = []
        outdated_instances.each do |i|
          # Terminated instances won't have attached volumes.
          next if instance_in_terminal_state?(i)

          begin
            inst = Aws::EC2::Instance.new(id: i.id)
            first_block_device = inst.block_device_mappings.first
            volumes << first_block_device[:ebs][:volume_id] if first_block_device
          rescue StandardError => e
            # We're catching all errors here, because failing to reap a volume
            # is not a critical error, will not cause issues with the update.
            @step.failure('Failed to get volumes for instance '\
                      "#{i.instance_id}: #{e.message}")
          end
        end
        volumes
      end

      # Cycle the instances in the ASG.
      #
      # Each instance will be detached one at a time, waiting for the new instance
      # to be ready before stopping the worker and terminating the instance.
      #
      # @param instances [Array] (outdated instances)
      #   List of instances to cycle. Defaults to all instances with outdated
      #   launch configurations.
      # @return [Array] (array of Aws::AutoScaling::Instance)
      #   List of shutdown instances.
      def cycle_instances(outdated_instances)
        shutdown_instances = []

        if outdated_instances.empty?
          @step.success('No instances cycled!')
          return []
        end

        @step.success("Cycling #{outdated_instances.size} " \
                      "of #{asg.instances.size} instances in " \
                      "#{physical_resource_id}...")

        # Iterate over the instances in the stack, detaching and terminating each
        # one.
        outdated_instances.each do |i|
          next if instance_in_terminal_state?(i)

          wait_for_instance(i)
          next unless detach_instance(i)

          @step.continue("Shutting down #{i.instance_id}")
          shutdown_instance(i.instance_id)
          shutdown_instances << i
          @step.success("Shut down #{i.instance_id}")
        end

        @ilog.info('All instances cycled.')

        shutdown_instances
      end

      # Waits for an instance to reach a ready state.
      #
      # @param instance [Aws::AutoScaling::Instance] Auto scaling instance to wait
      #   for.
      def wait_for_instance(instance, state = 'InService')
        instance.wait_until(max_attempts: 60, delay: 10) do |i|
          i.lifecycle_state == state
        end
      end

      # Detach an instance from its ASG. Re-attach if failed.
      #
      # @param instance [Aws::AutoScaling::Instance] Instance to detach.
      def detach_instance(instance)
        @step.success("Detaching instance: #{instance.instance_id}")

        # If the ASG can't be brought up to capacity, re-attach the instance.
        begin
          instance.detach(should_decrement_desired_capacity: false)
          @step.success('- Waiting for the AutoScaling '\
                       'Group to be up to capacity')
          wait_for_capacity
          true
        rescue Aws::AutoScaling::Errors::ValidationError => e
          raise e unless e.message.include?('is not part of Auto Scaling group')

          wait_for_capacity
          false
        rescue StandardError => e
          @step.failure("Error bringing the ASG up to capacity: #{e.message}")
          @step.failure("Attaching instance: #{instance.instance_id}")
          reattach_instance(instance)
          raise e
        end
      end

      # Re-attach an instance to its ASG.
      #
      # @param instance [Aws::AutoScaling::Instance] Instance to re-attach.
      def reattach_instance(instance)
        instance.load
        return unless instance.data.nil? \
          || %w[Detached Detaching].include?(instance.lifecycle_state)

        until instance.data.nil? || instance.lifecycle_state == 'Detached'
          sleep 10
          instance.load
        end
        instance.attach
      end

      # Terminate instances.
      #
      # @param instances [Array] (instances for termination)
      #   List of instances to terminate. Defaults to all instances with outdated
      #   launch configurations.
      def terminate_instances(shutdown_instances)
        @ilog.info("Terminate instances: #{shutdown_instances}")
        if shutdown_instances.any?
          @step.continue(
            "Terminating #{shutdown_instances.size} outdated instances..."
          )
        end
        shutdown_instances.each do |asg_instance|
          instance = Aws::EC2::Instance.new(asg_instance.instance_id)
          begin
            instance.load
          rescue Aws::EC2::Errors::InvalidInstanceIDNotFound
            next
          end

          next unless %w[stopping stopped].include?(instance.state[:name])

          instance.wait_until_stopped

          @step.continue("Terminating #{instance.instance_id}")
          instance.terminate
        end
      end

      def scale_asg(new_desired_capacity)
        @step.continue("Changing desired capacity of asg from #{asg.desired_capacity} to #{new_desired_capacity}...")
        asg.set_desired_capacity(desired_capacity: new_desired_capacity)
        wait_for_capacity
        @ilog.info("ASG desired capacity updated to #{new_desired_capacity}.")
      end

      def reap_volumes(volumes)
        volumes.each do |volume_id|
          @step.continue("Deleting volume: #{volume_id}")
          ec2_client(region: ENV['AWS_REGION'])
            .delete_volume(volume_id:)
        rescue StandardError => e
          # We're catching all errors here, because failing to reap a volume
          # is not a critical error, will not cause issues with the release.
          @step.failure("Failed to delete volume #{volume_id}: #{e.message}")
        end
      end

      # Waits for the ASG to reach the desired capacity.
      def wait_for_capacity
        @step.continue(
          'Waiting for Autoscaling group to reach desired capacity...'
        )
        # While we wait for the asg to reach capacity, report instance statuses
        # to the user.
        before_wait = proc do
          instances = []
          asg.reload.instances.each do |i|
            instances << " #{i.instance_id} (#{i.lifecycle_state})"
          end

          @step.continue("Instances: #{instances.join(', ')}")
        end

        asg.reload.wait_until(before_wait:, max_attempts: 60,
                              delay: 30) do |a|
          instances_up = a.instances.select do |i|
            i.lifecycle_state == 'InService'
          end
          instances_up.length == a.desired_capacity
        end
        @step.success('AutoScaling Group up to capacity!')
      end

      # Shuts down an instance, waiting for the instance to stop processing requests
      # first. We do this so that services will be stopped properly.
      #
      # @param id [String] ID of the instance to terminate.
      def shutdown_instance(id)
        instance = Aws::EC2::Instance.new(id:)
        return if instance_in_terminal_state?(instance)

        @ssh.exec('sudo shutdown -h now', id)
        instance.wait_until_stopped
      end

      def instance_in_terminal_state?(instance)
        state = if instance.is_a?(Aws::EC2::Instance)
                  check_ec2_instance(instance)
                elsif instance.is_a?(Aws::AutoScaling::Instance)
                  check_asg_instance(instance)
                end
        %w[Terminating Terminated].include?(state)
      end

      def check_ec2_instance(instance)
        @ilog.info("Check ec2 instance: #{instance}")
        if instance.exists?
          instance.state[:name]
        else
          'Terminated'
        end
      end

      def check_asg_instance(instance)
        if instance.load.data.nil?
          'Terminated'
        else
          instance.load.lifecycle_state
        end
      end
    end
  end
end
