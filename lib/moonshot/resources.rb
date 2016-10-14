module Moonshot
  # Resources is a dependency container that holds references to instances
  # provided to a Mechanism (build, deploy, etc.).
  class Resources
    attr_reader :stack, :ilog, :controller

    def initialize(stack:, ilog:, controller:)
      @stack = stack
      @ilog = ilog
      @controller = controller
    end
  end
end
