module Moonshot
  module Commands
    class Deploy < Moonshot::Command
      self.usage = 'deploy VERSION'
      self.description = 'Deploy a versioned release to the environment'

      def execute(version_name)
        controller.deploy_version(version_name)
      end
    end
  end
end
