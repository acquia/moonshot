require 'yaml'
require_relative 'stack_template'

module Moonshot
  # Handles YAML formatted AWS template files.
  class YamlStackTemplate < StackTemplate
    def body
      template_body.to_yaml
    end

    private

    def template_body
      @template_body ||= YAML.load_file(@filename)
    end
  end
end
