require_relative 'stack_parameter'

module Moonshot
  # A StackTemplate loads the template from disk and stores information
  # about it.
  class StackTemplate
    def initialize(filename)
      @filename = filename
    end

    def parameters
      template_body.fetch('Parameters', {}).map do |k, v|
        StackParameter.new(k,
                           default: v['Default'],
                           description: v.fetch('Description', ''))
      end
    end

    def resource_names
      template_body.fetch('Resources', {}).keys
    end

    def exist?
      File.exist?(@filename)
    end
  end
end
