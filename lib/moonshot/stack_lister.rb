# frozen_string_literal: true

module Moonshot
  # The StackLister is world renoun for it's ability to list stacks.
  class StackLister
    EnvironmentDescription = Struct.new(:name, :creation_time, :status)
    include CredsHelper

    def initialize(app_name)
      @app_name = app_name
    end

    # rubocop:disable Metrics/AbcSize
    def list # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      result = []
      next_token = nil
      loop do
        resp = cf_client.describe_stacks(next_token:)
        resp.stacks.each do |stack|
          app_tag = stack.tags.find { |t| t.key == 'moonshot_application' }
          env_tag = stack.tags.find { |t| t.key == 'moonshot_environment' }
          legacy_tag = stack.tags.find { |t| t.key == 'ah_stage' }

          if app_tag && app_tag.value == Moonshot.config.app_name
            result <<
              EnvironmentDescription.new(env_tag.value, stack.creation_time, stack.stack_status)
          elsif legacy_tag&.value&.start_with?(Moonshot.config.app_name)
            result <<
              EnvironmentDescription.new(legacy_tag.value, stack.creation_time, stack.stack_status)
          end
        end
        break unless resp.next_token

        next_token = resp.next_token
      end
      result.sort_by(&:name)
    end
    # rubocop:enable Metrics/AbcSize
  end
end
