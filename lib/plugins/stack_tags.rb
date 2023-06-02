# frozen_string_literal: true

require_relative '../tools/aws_resource_tags'

module Moonshot
  module Plugins
    # Cleanup bucket before network teardown.
    class StackTags
      def initialize()
        @tags
      end

      def pre_create(resources)
        stack_name = resources.stack.name
        env = if stack_name.include?('dev')
                'development'
              elsif stack_name.include?('test')
                'staging'
              else
                'production'
              end
        @tags = standard_tags(stack_name, env)
      end

      def standard_tags(stack_name, env)
        resource_tags = Acquia::Cloud::Data::Tools::AWSResourceTags.new(
          launch_env: env,
          stack_name: stack_name
        )
        resource_tags.tags.to_a.map { |o| { tag_key: o[0], tag_value: o[1] } }
      end

      alias pre_update pre_create
    end
  end
end
