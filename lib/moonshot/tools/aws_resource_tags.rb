# frozen_string_literal: true

module Acquia::Cloud::Data::Tools
  # Common tags for AWS resources
  class AWSResourceTags
    def initialize(launch_env:, stack_name:)
      @launch_env = launch_env
      @stack_name = stack_name
    end

    def tags
      standard_tags = {
        'acquia:bu' => 'dc',
        'acquia:stage' => "cloud-data-#{@stack_name}",
        'acquia:created_for' => 'cloud-data',
        'acquia:created_by' => 'cloud-data-service',
        'acquia:environment' => @launch_env
      }
      unless @launch_env == 'production'
        standard_tags['acquia:expiry'] = '9999-01-01'
        standard_tags['acquia:consumer'] = 'cloud-data'
      end
      standard_tags
    end
  end
end
