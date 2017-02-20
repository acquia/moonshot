module Moonshot
  # Choose a publically accessible instance to run commands on, given a Moonshot::Stack.
  class SSHTargetSelector
    def initialize(stack, asg_name: nil)
      @asg_name = asg_name
      @stack = stack
    end

    def choose!
      groups = @stack.resources_of_type('AWS::AutoScaling::AutoScalingGroup')

      asg = if groups.count == 1
              groups.first
            elsif groups.count > 1
              unless @asg_name
                raise 'Multiple Auto Scaling Groups found in the stack. Please specify which '\
                      'one to SSH into using the --auto-scaling-group (-g) option.'
              end
              groups.detect { |x| x.logical_resource_id == @asg_name }
            end
      raise 'Failed to find the Auto Scaling Group.' unless asg

      Aws::AutoScaling::Client.new.describe_auto_scaling_groups(
        auto_scaling_group_names: [asg.physical_resource_id]
      ).auto_scaling_groups.first.instances.map(&:instance_id).first
    rescue => e
      raise "Failed to select an instance from the Auto Scaling Group: #{e.message}"
    end
  end
end
