require 'colorize'

module Moonshot
  # A class for drawing hierarchical information using unicode lines.
  class UnicodeTable
    def initialize(name)
      @name = name
      @lines = []
      @children = []
    end

    def add_leaf(name)
      new_leaf = UnicodeTable.new(name)
      @children << new_leaf
      new_leaf
    end

    def add_line(line)
      @lines << line
      self
    end

    def add_table(table)
      # Calculate widths
      widths = []
      table.each do |line|
        line.each_with_index do |col, i|
          col = '?' unless col.respond_to?(:length)
          widths[i] = [widths[i] || 0, col.length].max
        end
      end

      format = widths.collect { |n| "%-#{n}s" }.join(' ') << "\n"
      table.each { |line| add_line(format(format, *line)) }
    end

    def draw(depth = 1, first = true)
      print first ? '┌' : '├'
      print '─' * depth
      puts ' ' << @name.light_black
      @lines = [''] + @lines + ['']
      @lines.each do |line|
        puts '│' << (' ' * depth) << line
      end
      @children.each do |child|
        child.draw(depth + 1, false)
      end
    end

    # Draw all children at the same level, for having multiple top-level
    # peer leaves.
    def draw_children
      first = true
      @children.each do |child|
        child.draw(1, first)
        first = false
      end
      puts '└──'
    end
  end
end
