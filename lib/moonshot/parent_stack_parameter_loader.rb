module Moonshot
  class ParentStackParameterLoader
    def initialize(config)
      @config = config
    end

    def load!
      @config.parent_stacks.each do |stack_name|
        count = 0

        resp = cf_client.describe_stacks(stack_name: stack_name)
        raise "Parent Stack #{stack_name} not found!" unless resp.stacks.size == 1

        # If there is an input parameters matching a stack output, pass it.
        resp.stacks[0].outputs.each do |output|
          next unless @config.parameters.key?(output.output_key)
          # Our Stack has a Parameter matching this output. Set it's
          # value to the Output's value.
          count += 1
          @config.parameters.fetch(output.output_key).set(output.output_value)
        end

        puts "Imported #{count} parameters from parent stack #{stack_name.blue}!" if count > 0
      end
    end

    def load_missing_only!
      @config.parent_stacks.each do |stack_name|
        resp = cf_client.describe_stacks(stack_name: stack_name)
        raise "Parent Stack #{stack_name} not found!" unless resp.stacks.size == 1

        # If there is an input parameters matching a stack output, pass it.
        resp.stacks[0].outputs.each do |output|
          next unless @config.parameters.key?(output.output_key)
          # Our Stack has a Parameter matching this output. Set it's
          # value to the Output's value, but only if we don't already
          # have a previous value we're using.
          unless @config.parameters.fetch(output.output_key).use_previous?
            @config.parameters.fetch(output.output_key).set(output.output_value)
          end
        end
      end
    end

    private

    def cf_client
      Aws::CloudFormation::Client.new
    end
  end
end
