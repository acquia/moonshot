# frozen_string_literal: true

module Moonshot
  module Commands
    module InteractiveCommand
      def parser
        parser = super

        parser.on('--[no-]interactive', TrueClass, 'Use interactive prompts.') do |v|
          Moonshot.config.interactive = v
        end
      end
    end
  end
end
