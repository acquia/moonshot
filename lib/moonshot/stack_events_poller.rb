module Moonshot
  # The StackEventsPoller queries DescribeStackEvents every time #latest_events
  # is invoked, filtering out events that have already been returned. It can
  # also, optionally, filter all non-error events (@see #show_errors_only).
  class StackEventsPoller
    def initialize(cf_client, stack_name)
      @cf_client = cf_client
      @stack_name = stack_name

      # Start showing events from now.
      @last_time = Time.now
    end

    def show_only_errors
      @errors_only = true
    end

    # Build a list of events that have occurred since the last call to this
    # method.
    #
    # @return [Array<Aws::CloudFormation::Event>]
    def latest_events
      events = get_stack_events.select do |event|
        event.timestamp > @last_time
      end

      @last_time = Time.now

      filter_events(events.sort_by(&:timestamp))
    end

    def filter_events(events)
      if @errors_only
        events.select do |event|
          %w[CREATE_FAILED UPDATE_FAILED DELETE_FAILED].include?(event.resource_status)
        end
      else
        events
      end
    end

    def get_stack_events(token = nil)
      opts = {
        stack_name: @stack_name
      }

      opts[:next_token] = token if token

      result = @cf_client.describe_stack_events(**opts)
      events = result.stack_events
      events += get_stack_events(result.next_token) if result.next_token

      events
    end
  end
end
