# coding: utf-8
require 'colorize'
require 'ruby-duration'

module Moonshot
  # Display information about the AutoScaling Groups, associated ELBs, and
  # managed instances to the user.
  class StackASGPrinter
    include CredsHelper

    def initialize(stack, table)
      @stack = stack
      @table = table
    end

    def print
      asgs.each do |asg|
        asg_info = as_client.describe_auto_scaling_groups(
          auto_scaling_group_names: [asg.physical_resource_id])
                            .auto_scaling_groups.first
        t_asg_info = @table.add_leaf("ASG: #{asg.logical_resource_id}")

        add_asg_info(t_asg_info, asg_info)
        instances_leaf = t_asg_info.add_leaf('Instances')

        if asg_info.instances.empty?
          instances_leaf.add_line('There are no instances in this Auto-Scaling Group.')
        else
          instances_leaf.add_table(create_instance_table(asg_info))
        end

        add_recent_activity_leaf(t_asg_info, asg.physical_resource_id)
      end
    end

    private

    def asgs
      @stack.resources_of_type('AWS::AutoScaling::AutoScalingGroup')
    end

    def status_with_color(status)
      case status
      when 'Successful'
        status.green
      when 'Failed'
        status.red
      else
        status.yellow
      end
    end

    def lifecycle_color(lifecycle)
      case lifecycle
      when 'InService'
        lifecycle.green
      else
        lifecycle.red
      end
    end

    def health_color(health)
      case health
      when 'Healthy'
        health.green
      else
        health.red
      end
    end

    # Get additional information about instances not returned by the ASG API.
    def get_addl_info(instance_ids)
      resp = ec2_client.describe_instances(instance_ids: instance_ids)

      data = {}
      resp.reservations.map(&:instances).flatten.each do |instance|
        data[instance.instance_id] = instance
      end
      data
    end

    def add_asg_info(table, asg_info)
      name = asg_info.auto_scaling_group_name.blue
      table.add_line "Name: #{name}"

      hc = asg_info.health_check_type.blue
      gp = (asg_info.health_check_grace_period.to_s << 's').blue
      table.add_line "Using #{hc} health checks, with a #{gp} health check grace period." # rubocop:disable LineLength

      dc = asg_info.desired_capacity.to_s.blue
      min = asg_info.min_size.to_s.blue
      max = asg_info.max_size.to_s.blue
      table.add_line "Desired Capacity is #{dc} (Min: #{min}, Max: #{max})."

      lbs = asg_info.load_balancer_names
      table.add_line "Has #{lbs.count.to_s.blue} Load Balancer(s): #{lbs.map(&:blue).join(', ')}" # rubocop:disable LineLength
    end

    def create_instance_table(asg_info)
      current_lc = asg_info.launch_configuration_name
      ec2_info = get_addl_info(asg_info.instances.map(&:instance_id))
      asg_info.instances.map do |asg_instance|
        row = instance_row(asg_instance,
                           ec2_info[asg_instance.instance_id])
        row << if current_lc == asg_instance.launch_configuration_name
                 '(launch config up to date)'.green
               else
                 '(launch config out of date)'.red
               end
      end
    end

    def instance_row(asg_instance, ec2_instance)
      if ec2_instance
        if ec2_instance.public_ip_address
          ip_address = "#{ec2_instance.public_ip_address} (#{ec2_instance.private_ip_address})"
        else
          ip_address = "#{ec2_instance.private_ip_address} (PRV)"
        end
        uptime = uptime_format(ec2_instance.launch_time)
      else
        # We've seen race conditions where ASG tells us about instances that EC2 is no longer
        # aware of.
        ip_address = 'unknown'
        uptime = 'unknown'
      end
      [
        asg_instance.instance_id,
        ip_address,
        lifecycle_color(asg_instance.lifecycle_state),
        health_color(asg_instance.health_status),
        uptime
      ]
    end

    def uptime_format(launch_time)
      # %td is "total days", instead of counting up again to weeks.
      Duration.new(Time.now.to_i - launch_time.to_i)
              .format('%tdd %hh %mm %ss')
    end

    def add_recent_activity_leaf(table, asg_name)
      recent = table.add_leaf('Recent Activity')
      resp = as_client.describe_scaling_activities(
        auto_scaling_group_name: asg_name).activities

      rows = resp.sort_by(&:start_time).reverse.first(10).map do |activity|
        row_for_activity(activity)
      end

      recent.add_table(rows)
    end

    def row_for_activity(activity)
      [
        activity.start_time.to_s.light_black,
        activity.description,
        status_with_color(activity.status_code),
        activity.progress.to_s << '%'
      ]
    end
  end
end
