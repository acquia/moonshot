require_relative 'parameter_arguments'

module Moonshot
  module Commands
    class Update < Moonshot::Command
      include ParameterArguments

      self.usage = 'update [options]'
      self.description = 'Update the CloudFormation stack within an environment.'

      def execute
        controller.update
      end

      private

      def parameter_strategy_factory(value)
        case value.to_sym
        when :default
          Moonshot::ParameterStrategy::DefaultStrategy.new
        when :merge
          Moonshot::ParameterStrategy::MergeStrategy.new
        else
          raise "Unknown parameter strategy: #{value}"
        end
      end
    end
  end
end
