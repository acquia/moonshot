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
        parser.on('-d', '--[no-]deploy', TrueClass, 'Choose if code should be deployed immediately after the stack is created') do |v| # rubocop:disable LineLength
          @deploy = v
        end

        parser.on('--version VERSION_NAME', 'Version for initial deployment. If unset, a new development build is created from the local directory') do |v| # rubocop:disable LineLength
          @version = v
        end

        parser.on('--template-file=FILE', 'Override the path to the CloudFormation template.') do |v|
          Moonshot.config.template_file = v
        end

        parser.on('--tag KEY=VALUE', '-TKEY=VALUE', 'Specify stack tags on the command line') do |v|
          data = v.split('=', 2)
          unless data.size == 2
            raise "Invalid tag format '#{v}', expected KEY=VALUE (e.g. MyStackTag=12)"
          end

          Moonshot.config.extra_tags << { key: data[0], value: data[1] }
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
