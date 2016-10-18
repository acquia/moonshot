module Moonshot
  # The StackLister is world renoun for it's ability to list stacks.
  class StackLister
    EnvironmentDescription = Struct.new(:name, :creation_time, :status)
    include CredsHelper

    def initialize(app_name)
      @app_name = app_name
    end

    def list
      result = []
      next_token = nil
      loop do
        resp = cf_client.describe_stacks(next_token: next_token)
        resp.stacks.each do |stack|
          app_tag = stack.tags.find { |t| t.key == 'moonshot_application' }
          env_tag = stack.tags.find { |t| t.key == 'moonshot_environment' }

          next unless app_tag && app_tag.value == Moonshot.config.app_name
          result <<
            EnvironmentDescription.new(env_tag.value, stack.creation_time, stack.stack_status)
        end
        break unless resp.next_token
        next_token = resp.next_token
      end
      result.sort_by(&:name)
    end
  end
end
