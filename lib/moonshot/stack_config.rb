# frozen_string_literal: true

module Moonshot
  # Configuration for the Moonshot::Stack class.
  class StackConfig
    attr_accessor :parent_stacks, :show_all_events

    def initialize
      @parent_stacks = []
      @show_all_events = false
    end
  end
end
