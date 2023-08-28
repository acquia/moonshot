# frozen_string_literal: true

module Moonshot
  module Commands
    module ShowAllEventsOption
      def parser
        parser = super

        parser.on('--[no-]show-all-events', TrueClass, 'Show all stack events during update') do |v|
          Moonshot.config.show_all_stack_events = v
        end
      end
    end
  end
end
