# frozen_string_literal: true

require 'json'
require_relative 'stack_template'

module Moonshot
  # Handles JSON formatted AWS template files.
  class JsonStackTemplate < StackTemplate
    def body
      template_body.to_json
    end

    private

    def template_body
      @template_body ||= JSON.parse(File.read(@filename))
    end
  end
end
