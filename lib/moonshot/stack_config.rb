module Moonshot
  # Configuration for the Moonshot::Stack class.
  class StackConfig
    attr_accessor :parent_stacks
    attr_accessor :show_all_events
    attr_accessor :parameter_strategy

    def initialize
      @parent_stacks = []
      @show_all_events = false
    end
  end
end
