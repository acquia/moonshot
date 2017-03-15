module Moonshot
  module Commands
    class Update < Moonshot::Command
      include ParameterArguments
      include ShowAllEventsOption
      include ParentStackOption

      self.usage = 'update [options]'
      self.description = 'Update the CloudFormation stack within an environment.'

      def parser
        parser = super

        parser.on('--dry-run', TrueClass, 'Show the changes that would be applied, but do not execute them') do |v| # rubocop:disable LineLength
          @dry_run = v
        end

        parser.on('--force', '-f', TrueClass, 'Apply ChangeSet without confirmation') do |v|
          @force = v
        end

        parser.on('--refresh-parameters', TrueClass, 'Update parameters from parent stacks') do |v|
          @refresh_parameters = v
        end
      end

      def execute
        @force = true unless Moonshot.config.interactive
        controller.update(dry_run: @dry_run, force: @force, refresh_parameters: @refresh_parameters)
      end
    end
  end
end
