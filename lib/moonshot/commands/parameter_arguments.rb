# rubocop:disable LineLength
module Moonshot
  module Commands
    module ParameterArguments
      def parser
        parser = super

        parser.on('--[no-]interactive', TrueClass, 'Use interactive prompts for gathering missing configuration.') do |v|
          Moonshot.config.interactive = v
        end

        parser.on('--answer-file FILE', '-aFILE', 'Load Stack Parameters from a YAML file') do |v|
          Moonshot.config.answer_file = File.expand_path(v)
        end

        parser.on('--parameter KEY=VALUE', '-PKEY=VALUE', 'Specify Stack Parameter on the command line') do |v|
          data = v.split('=', 2)
          unless data.size == 2
            raise "Invalid parameter format '#{v}', expected KEY=VALUE (e.g. MyStackParameter=12)"
          end

          Moonshot.config.parameter_overrides[data[0]] = data[1]
        end
      end
    end
  end
end
