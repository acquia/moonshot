module Moonshot
  module Commands
    class Update < Moonshot::Command
      self.usage = 'update [options]'
      self.description = 'Update the CloudFormation stack within an environment.'

      def parser
        parser = super
        parser.on('--parameter-strategy default,merge', 'Override default parameter strategy') do |v| # rubocop:disable LineLength
          Moonshot.config.parameter_strategy = parameter_strategy_factory(v)
        end
      end

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
