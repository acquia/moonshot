module Moonshot
  module Tools
    class ASGRollout # rubocop:disable ClassLength
      attr_accessor :config

      def initialize(controller:, logical_id:)
        @config = ASGRolloutConfig.new
        @controller = controller
        @logical_id = logical_id
        yield @config if block_given?
      end

      def run!
        increase_max_and_desired
        loop do
          new_instance = wait_for_new_instance
          begin
            wait_for_in_service(new_instance)
          rescue
            next
          end
          break
        end
        targets = asg.non_conforming_instances
        last_instance = targets.last

        targets.each do |instance|
          run_pre_detach(instance) if @config.pre_detach
          detach(instance, decrement: instance == last_instance)
          wait_for_out_of_service(instance)

          unless instance == last_instance
            new_instance = wait_for_new_instance
            wait_for_in_service(new_instance)
          end

          wait_for_terminate_when_hook(instance) if @config.terminate_when
          terminate(instance)
        end
      ensure
        log.start_threaded 'Restoring MaxSize/DesiredCapacity values to normal...' do |s|
          asg.set_max_and_desired(@max, @desired)
          s.success 'Restored MaxSize/DesiredCapacity values to normal!'
        end
      end

      private

      def increase_max_and_desired
        log.start_threaded 'Increasing MaxSize/DesiredCapacity by 1.' do |s|
          @max, @desired = asg.current_max_and_desired
          asg.set_max_and_desired(@max + 1, @desired + 1)
          s.success 'Increased MaxSize/DesiredCapacity by 1.'
        end
      end

      def wait_for_new_instance
        new_instance = nil
        log.start_threaded 'Waiting for a new instance to join Auto Scaling Group...' do |s|
          new_instance = asg.wait_for_new_instance
          s.success "A wild #{new_instance.blue} appears!"
        end
        new_instance
      end

      def wait_for_in_service(new_instance)
        log.start_threaded "Waiting for #{new_instance.blue} to be InService..." do |s|
          instance_health = nil

          loop do
            instance_health = asg.instance_health(new_instance)
            if instance_health.out_of_service?
              s.failure "Instance #{new_instance.blue} went OutOfService while waiting to join..."
              raise "Instance #{new_instance.blue} went OutOfService while waiting to join..."
            end
            break if instance_health.in_service?
            s.continue "Instance #{new_instance.blue} is #{instance_health}..."
            sleep @config.instance_health_delay
          end

          s.success "Instance #{new_instance.blue} is #{instance_health}!"
        end
      end

      def run_pre_detach(instance)
        if @config.pre_detach
          log.start_threaded "Running PreDetach hook on #{instance.blue}..." do |s|
            he = HookExecEnvironment.new(@controller.config, instance)
            if false == @config.pre_detach.call(he)
              s.failure "PreDetach hook failed for #{instance.blue}!"
              raise "PreDetach hook failed for #{instance.blue}!"
            end

            s.success "PreDetach hook complete for #{instance.blue}!"
          end
        end
      end

      def detach(instance, decrement:)
        log.start_threaded "Detaching instance #{instance.blue}..." do |s|
          asg.detach_instance(instance, decrement: decrement)

          if decrement
            s.success "Detached instance #{instance.blue}, and decremented DesiredCapacity."
          else
            s.success "Detached instance #{instance.blue}."
          end
        end
      end

      def wait_for_out_of_service(instance)
        log.start_threaded "Waiting for #{instance.blue} to be OutOfService..." do |s|
          instance_health = nil

          loop do
            instance_health = asg.instance_health(instance)
            break if instance_health.out_of_service?
            s.continue "Instance #{instance.blue} is #{instance_health}..."
            sleep @config.instance_health_delay
          end

          s.success "Instance #{instance.blue} is #{instance_health}!"
        end
      end

      def wait_for_terminate_when_hook(instance)
        log.start_threaded "Waiting for TerminateWhen hook for #{instance.blue}..." do |s|
          start = Time.now.to_f
          he = HookExecEnvironment.new(@controller.config, instance)
          timeout = @config.terminate_when_timeout

          loop do
            if @config.terminate_when.call(he)
              s.success "Completed TerminateWhen check for #{instance.blue}!"
              break
            end
            sleep @config.terminate_when_delay
            if Time.now.to_f - start > timeout
              s.failure "TerminateWhen for #{instance.blue} did not complete in #{timeout} seconds!"
              break
            end
          end
        end
      end

      def terminate(instance)
        log.start_threaded "Terminating #{instance.blue}..." do |s|
          he = HookExecEnvironment.new(@controller.config, instance)
          @config.terminate.call(he)
          s.success "Terminated #{instance.blue}!"
        end
      end

      def asg
        return @asg if @asg

        asg_name = @controller.stack.physical_id_for(@logical_id)
        unless asg_name
          raise "Could not find Auto Scaling Group #{@logical_id}!"
        end

        @asg ||= ASGRollout::ASG.new(asg_name)
      end

      def log
        @controller.config.interactive_logger
      end
    end
  end
end
