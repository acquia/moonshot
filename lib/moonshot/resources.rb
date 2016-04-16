module Moonshot
  # Resources is a dependency container that holds references to instances
  # provided to a Mechanism (build, deploy, etc.).
  class Resources
    attr_reader :stack, :ilog

    def initialize(stack:, ilog:)
      @stack = stack
      @ilog = ilog
    end
  end
end
