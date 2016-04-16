module Moonshot
  module Commands
    class Build < Moonshot::Command
      self.usage = 'build VERSION'
      self.description = 'Build a release artifact, ready for deployment'

      def execute(version_name)
        controller.build_version(version_name)
      end
    end
  end
end
