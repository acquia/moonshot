module Moonshot
  module Commands
    class GenerateTemplate < Moonshot::Command
      self.usage = 'generate-template [options]'
      self.description = 'Processes an ERB formatted CloudFormation template.'

      def initialize(*)
        super
        @parameters = {}
      end

      def parser
        parser = super

        parser.on('--source SOURCE_FILE', 'The ERB template file.') do |v|
          @source = v
        end

        parser.on('--parameter KEY=VALUE', '-PKEY=VALUE',
                  'Specify Stack Parameter on the command line') do |v|
          data = v.split('=', 2)
          unless data.size == 2
            raise "Invalid parameter format '#{v}',"\
                  'expected KEY=VALUE (e.g. MyTemplateParameter=12)'
          end

          @parameters[data[0]] = data[1]
        end

        parser.on('--destination DESTINATION_FILE', 'Destionation file.') do |v|
          @destination = v
        end
      end

      def execute
        ::Moonshot::DynamicTemplate.new(
          source: @source,
          parameters: @parameters,
          destination: @destination
        ).process
      end
    end
  end
end
