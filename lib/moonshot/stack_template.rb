module Moonshot
  # A StackTemplate loads the template from disk and stores information
  # about it.
  class StackTemplate
    Parameter = Struct.new(:name, :default) do
      def required?
        default.nil?
      end
    end

    def initialize(filename, log:)
      @log = log
      @filename = filename
    end

    def parameters
      template_body.fetch('Parameters', {}).map do |k, v|
        Parameter.new(k, v['Default'])
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
