# frozen_string_literal: true

require 'colorize'

module Moonshot
  class AskUserSource
    def get(param)
      return unless Moonshot.config.interactive

      @param = param

      prompt
      loop do
        input = gets.chomp

        if String(input).empty? && @param.default?
          # We will use the default value, print it here so the output is clear.
          puts 'Using default value.'
          return
        elsif String(input).empty?
          puts "Cannot proceed without value for #{@param.name}!"
        else
          @param.set(String(input))
          return
        end

        prompt
      end
    end

    private

    def prompt
      print "(#{@param.name})".light_black
      print " #{@param.description}" unless @param.description.empty?
      print " [#{@param.default}]".light_black if @param.default?
      print ': '
    end
  end
end
