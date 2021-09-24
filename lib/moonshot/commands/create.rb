# frozen_string_literal: true

require_relative 'parameter_arguments'
require_relative 'show_all_events_option'
require_relative 'parent_stack_option'

module Moonshot
  module Commands
    class Create < Moonshot::Command
      include ParameterArguments
      include ShowAllEventsOption
      include ParentStackOption

      self.usage = 'create [options]'
      self.description = 'Create a new environment'

      attr_reader :version, :deploy

      def parser
        @deploy = true

        parser = super
        desc = 'Choose if code should be deployed immediately after the stack is created'
        parser.on('-d', '--[no-]deploy', TrueClass, desc) do |v|
          @deploy = v
        end

        desc = 'Version for initial deployment. If unset, a new development build is created from the local directory'
        parser.on('--version VERSION_NAME', desc) do |v|
          @version = v
        end

        parser.on('--template-file=FILE', 'Override the path to the CloudFormation template.') do |v|
          Moonshot.config.template_file = v
        end
      end

      def execute
        controller.create

        if @deploy && @version.nil?
          controller.push
        elsif @deploy
          controller.deploy_version(@version)
        end
      end
    end
  end
end
