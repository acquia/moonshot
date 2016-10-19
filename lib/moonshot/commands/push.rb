module Moonshot
  module Commands
    class Push < Moonshot::Command
      self.usage = 'push [options]'
      self.description = 'Build and deploy a development artifact from the working directory'

      def execute
        controller.push
      end
    end
  end
end
