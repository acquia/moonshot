require 'colorize'

module Moonshot
  class AskUserSource
    def get(sp)
      return unless Moonshot.config.interactive

      @sp = sp

      prompt
      loop do
        input = gets.chomp

        if String(input).empty? && @sp.default?
          # We will use the default value, print it here so the output is clear.
          puts 'Using default value.'
          return
        elsif String(input).empty?
          puts "Cannot proceed without value for #{@sp.name}!"
        else
          @sp.set(String(input))
          return
        end

        prompt
      end
    end

    private

    def prompt
      print "(#{@sp.name})".light_black
      print " #{@sp.description}" unless @sp.description.empty?
      print " [#{@sp.default}]".light_black if @sp.default?
      print ': '
    end
  end
end
