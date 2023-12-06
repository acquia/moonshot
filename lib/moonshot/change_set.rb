# frozen_string_literal: true

module Moonshot
  class ChangeSet
    attr_reader :name, :stack_name

    def initialize(name, stack_name)
      @name = name
      @stack_name = stack_name
      @change_set = nil
      @cf_client = Aws::CloudFormation::Client.new
    end

    def confirm?
      raise 'Cannot confirm ChangeSet when interactive mode is disabled!' unless Moonshot.config.interactive

      loop do
        print 'Apply changes? '
        resp = gets.chomp.downcase

        return true if resp == 'yes'
        return false if resp == 'no'

        puts "Please enter 'yes' or 'no'!"
      end
    end

    def valid?
      @change_set.status == 'CREATE_COMPLETE'
    end

    def invalid_reason
      @change_set.status_reason
    end

    def display_changes # rubocop:disable Metrics/CyclomaticComplexity
      wait_for_change_set unless @change_set

      @change_set.changes.map(&:resource_change).each do |c|
        puts "* #{c.action} #{c.logical_resource_id} (#{c.resource_type})"

        case c.replacement
        when 'True'
          puts ' - Will be replaced'
        when 'Conditional'
          puts ' - May be replaced (Conditional)'
        end

        c.details.each do |d|
          case d.change_source
          when 'ResourceReference', 'ParameterReference'
            puts " - Caused by #{d.causing_entity.blue} (#{d.change_source})"
          when 'DirectModification'
            puts " - Caused by template change (#{d.target.attribute}: #{d.target.name})"
          end
        end
      end
    end

    def execute
      wait_for_change_set unless @change_set
      @cf_client.execute_change_set(
        change_set_name: @name,
        stack_name: @stack_name
      )
    end

    def delete
      wait_for_change_set unless @change_set
      @cf_client.delete_change_set(
        change_set_name: @name,
        stack_name: @stack_name
      )
    rescue Aws::CloudFormation::Errors::InvalidChangeSetStatus
      sleep 1
      retry
    end

    # NOTE: At the time of this patch, AWS-SDK native Waiters do not
    # have support for ChangeSets. Once they add this, we can make
    # this code much better.
    # Still no support for this waiter, but it's planned.
    # https://github.com/aws/aws-sdk-ruby/issues/1388
    def wait_for_change_set
      wait_seconds = Moonshot.config.changeset_wait_time || 90
      start = Time.now.to_i

      loop do
        resp = @cf_client.describe_change_set(
          change_set_name: @name,
          stack_name: @stack_name
        )

        if %w[CREATE_COMPLETE FAILED].include?(resp.status)
          @change_set = resp
          return
        end

        if Time.now.to_i > start + wait_seconds
          raise "ChangeSet did not complete creation within #{wait_seconds} seconds!"
        end

        sleep 5 # http://bit.ly/1qY1ZXJ
        # Wait 5 seconds because other waiters seem to wait at least 5 seconds
        # before repeating requests.
        # See: https://github.com/aws/aws-sdk-ruby/blob/master/aws-sdk-core/apis/cloudformation/2010-05-15/waiters-2.json#L5
      end
    end
  end
end
