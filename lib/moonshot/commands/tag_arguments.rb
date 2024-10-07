# frozen_string_literal: true

module Moonshot
  module Commands
    module TagArguments
      def parser
        parser = super

        parser.on('--tag KEY=VALUE', '-TKEY=VALUE', 'Specify Stack Tag on the command line') do |v|
          data = v.split('=', 2)
          unless data.size == 2
            raise "Invalid tag format '#{v}', expected KEY=VALUE (e.g. MyStackTag=12)"
          end

          Moonshot.config.extra_tags << { key: data[0], value: data[1] }
        end
      end
    end
  end
end
