module Moonshot
  module Commands
    class Ssh < Moonshot::SSHCommand
      self.usage = 'ssh [options]'
      self.description = 'SSH into the first (or specified) instance on the stack'

      def execute
        controller.ssh
      end
    end
  end
end
