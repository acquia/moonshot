# frozen_string_literal: true

module Moonshot
  module Commands
    class List < Moonshot::Command
      self.usage = 'list [options]'
      self.description = 'List stacks for this application'

      def execute
        stacks = StackLister.new(controller.config.app_name).list
        StackListPrinter.new(stacks).print
      end
    end
  end
end
