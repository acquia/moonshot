# frozen_string_literal: true

module Moonshot
  class ChangeSetTimeoutError < StandardError; end

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

    def wait_for_change_set
      wait_seconds = Moonshot.config.changeset_wait_time || 90

      resp = @cf_client.describe_change_set({
        stack_name: @stack_name,
        change_set_name: @name
      })

      if %w(CREATE_COMPLETE FAILED).include?(resp.status)
        @change_set = resp
        return
      end

      started_at = Time.now
      @cf_client.wait_until(:change_set_create_complete, {
        stack_name: @stack_name,
        change_set_name: @name
      }, {
        max_attempts: nil,
        delay: 5,
        before_wait: -> (attempts, response) do
          raise ChangeSetTimeoutError, "ChangeSet did not complete creation within #{wait_seconds} seconds!" if Time.now - started_at > wait_seconds
        end
      })

      @change_set = @cf_client.describe_change_set({
        stack_name: @stack_name,
        change_set_name: @name
      })
    end
  end
end
