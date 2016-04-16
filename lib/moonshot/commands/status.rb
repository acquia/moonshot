module Moonshot
  module Commands
    class Status < Moonshot::Command
      self.usage = 'status [options]'
      self.description = 'Show the status of an existing environment'

      def execute
        controller.status
      end
    end
  end
end
