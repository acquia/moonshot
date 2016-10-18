module Moonshot
  class StackListPrinter
    attr_accessor :stacks

    def initialize(stacks)
      @stacks = stacks
      @table = UnicodeTable.new('Environment List')
    end

    def print
      rows = @stacks.map do |stack|
        [stack.name, stack.creation_time, stack.status]
      end

      @table.add_table(rows)

      @table.draw
      @table.draw_children
    end
  end
end
