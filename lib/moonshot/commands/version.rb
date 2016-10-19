module Moonshot
  module Commands
    class Version < Moonshot::Command
      self.usage = 'version'
      self.description = 'Display the version of Moonshot'

      def execute
        puts Gem.loaded_specs['moonshot'].version
      end
    end
  end
end
