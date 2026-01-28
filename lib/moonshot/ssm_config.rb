# frozen_string_literal: true

module Moonshot
  class SSMConfig
    attr_accessor :enabled

    def initialize
      @enabled = true
    end
  end
end
