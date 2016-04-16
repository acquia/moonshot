module Moonshot
  module Commands
    class Doctor < Moonshot::Command
      self.usage = 'doctor [options]'
      self.description = 'Run configuration checks against the local environment'

      def execute
        controller.doctor || raise('One or more checks failed.')
      end
    end
  end
end
