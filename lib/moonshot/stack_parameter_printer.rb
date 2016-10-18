module Moonshot
  # Displays information about existing stack parameters to the user, with
  # information on what a stack update would do.
  class StackParameterPrinter
    def initialize(stack, table)
      @stack = stack
      @table = table
    end

    def print
      p_table = @table.add_leaf('Stack Parameters')
      rows = @stack.parameters.sort.map do |key, value|
        ["#{key}:", format_value(value)]
      end

      p_table.add_table(rows)
    end

    def format_value(value)
      if value.size > 60
        value[0..60] + '...'
      else
        value
      end
    end
  end
end
