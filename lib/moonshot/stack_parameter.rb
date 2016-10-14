module Moonshot
  class StackParameter
    attr_reader :name
    attr_reader :default

    def initialize(name, default: nil, use_previous: false)
      @name = name
      @default = default
      @use_previous = use_previous
      @value = nil
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

    def use_previous!
      if @value
        raise "Value already set for StackParameter #{@name}, cannot use previous value!"
      end

      @use_previous = true
    end

    def value
      unless @value || default?
        raise "No value set and no default for StackParameter #{@name}!"
      end

      if @use_previous
        raise "StackParameter #{@name} is using previous value, not set!"
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
