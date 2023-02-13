# frozen_string_literal: true

module Moonshot
  module Commands
    class Deploy < Moonshot::Command
      include InteractiveCommand

      self.usage = 'deploy VERSION'
      self.description = 'Deploy a versioned release to the environment'

      def execute(version_name)
        controller.deploy_version(version_name)
      end
    end
  end
end
