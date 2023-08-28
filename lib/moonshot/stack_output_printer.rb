# frozen_string_literal: true

module Moonshot
  # Display the stack outputs to the user.
  class StackOutputPrinter
    def initialize(stack, table)
      @stack = stack
      @table = table
    end

    def print
      o_table = @table.add_leaf('Stack Outputs')
      rows = @stack.outputs.sort.map do |key, value|
        ["#{key}:", value]
      end
      o_table.add_table(rows)
    end
  end
end
