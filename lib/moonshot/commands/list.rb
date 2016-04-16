module Moonshot
  module Commands
    class List < Moonshot::Command
      self.usage = 'list [options]'
      self.description = 'List stacks for this application'

      def execute
        controller.list
      end
    end
  end
end
