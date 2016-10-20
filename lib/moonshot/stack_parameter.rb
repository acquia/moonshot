module Moonshot
  class StackParameter
    attr_reader :name
    attr_reader :default
    attr_reader :description

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
      if @value
        raise "Value already set for StackParameter #{@name}, cannot use previous value!"
      end

      # Make the current value available to plugins.
      @value = value
      @use_previous = true
    end

    def value
      unless @value || default?
        raise "No value set and no default for StackParameter #{@name}!"
      end

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
