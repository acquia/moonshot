# frozen_string_literal: true

module Moonshot
  class StackParameter
    attr_reader :name, :default, :description

    def initialize(name, default: nil, use_previous: false, description: '')
      @default      = default
      @description  = description
      @name         = name
      @use_previous = use_previous
      @value        = nil
    end

    # Does this Stack Parameter have a default value that will be used?
    def default?
      !@default.nil?
    end

    def use_previous?
      @use_previous ? true : false
    end

    # Has the user provided a value for this parameter?
    def set?
      !@value.nil?
    end

    def set(value)
      @value = value
      @use_previous = false
    end

    def use_previous!(value)
      raise "Value already set for StackParameter #{@name}, cannot use previous value!" if @value

      # Make the current value available to plugins.
      @value = value
      @use_previous = true
    end

    def value
      raise "No value set and no default for StackParameter #{@name}!" unless @value || default?

      @value || default
    end

    def to_cf
      result = { parameter_key: @name }

      if use_previous?
        result[:use_previous_value] = true
      else
        result[:parameter_value] = value
      end

      result
    end
  end
end
