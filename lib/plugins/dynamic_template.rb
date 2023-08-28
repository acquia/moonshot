# frozen_string_literal: true

module Moonshot
  module Plugins
    class DynamicTemplate
      def initialize(source:, parameters:, destination:)
        @dynamic_template = ::Moonshot::DynamicTemplate.new(
          source:,
          parameters:,
          destination:
        )
      end

      def run_hook
        @dynamic_template.process
      end

      def cli_hook(parser)
        parser.on('--template-file=FILE', 'Override the path to the CloudFormation template.') do |v|
          @dynamic_template.destination = v
          Moonshot.config.template_file = v
        end
      end

      # Moonshot hooks to trigger this plugin.
      alias setup_create run_hook
      alias setup_update run_hook
      alias setup_delete run_hook

      # Moonshot hooks to add CLI options.
      alias create_cli_hook cli_hook
      alias delete_cli_hook cli_hook
      alias update_cli_hook cli_hook
    end
  end
end
