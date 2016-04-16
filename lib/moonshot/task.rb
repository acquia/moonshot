module Moonshot
  class Task
    attr_reader :name, :desc, :block
    def initialize(name, desc, &block)
      @name = name.to_sym
      @desc = desc
      @block = block
    end
  end
end
