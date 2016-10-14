module Moonshot
  # A Rigid Hash-like structure that only accepts manipulation of
  # parameters defined in the Stack template. Anything else results in
  # an exception.
  class ParameterCollection
    extend Forwardable

    def_delegators :@hash, :key?, :fetch, :[], :keys, :values

    def self.from_template(template)
      obj = new

      template.parameters.each do |stack_parameter|
        obj.add(stack_parameter)
      end

      obj
    end

    def initialize
      @hash = {}
    end

    def []=(key, value)
      raise "Invalid StackParameter #{key}!" unless @hash.key?(key)

      @hash[key].set(value)
    end

    def add(parameter)
      raise ArgumentError, 'Can only add StackParameters!' unless parameter.is_a?(StackParameter)

      @hash[parameter.name] = parameter
    end

    # What parameters are missing for a CreateStack call, where
    # UsePreviousValue has no meaning.
    def missing_for_create
      # If we haven't set a value, and there is no default, we can't
      # create the stack.
      @hash.values.select { |v| !v.set? && !v.default? }
    end

    def missing_for_update
      # If we don't have a previous value to use, we haven't set a
      # value, and there is no default, we can't update a stack.
      @hash.values.select { |v| !v.set? && !v.default? && !v.use_previous? }
    end
  end
end
