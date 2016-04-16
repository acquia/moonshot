require 'thor'

module Moonshot
  # This class implements the command-line `moonshot` tool.
  class CommandLine < Thor
    def self.run!
      orig_dir = Dir.pwd

      loop do
        break if File.exist?('Moonfile')

        if Dir.pwd == '/'
          warn 'Could not find Moonfile!'
          exit 1
        else
          Dir.chdir('..')
        end
      end

      moonfile_dir = Dir.pwd
      Dir.chdir(orig_dir)

      # TODO: This is to keep the configuration looking roughly the same, maybe
      # we should just accept that some of these are long?
      Object.include(Moonshot::ArtifactRepository)
      Object.include(Moonshot::BuildMechanism)
      Object.include(Moonshot::DeploymentMechanism)
      load(File.join(moonfile_dir, 'Moonfile'))

      # Now that we've defined global configuration, run the Thor tooling.
      CommandLine.start
    end

    class_option(:name, aliases: 'n', default: nil, type: :string)
    class_option(:interactive_logger, type: :boolean, default: true)
    class_option(:verbose, aliases: 'v', type: :boolean)

    def self.exit_on_failure?
      true
    end

    def initialize(*args)
      super
      @log = Logger.new(STDOUT)
      @log.formatter = proc do |s, d, _, msg|
        "[#{s} #{d.strftime('%T')}] #{msg}\n"
      end
      @log.level = options[:verbose] ? Logger::DEBUG : Logger::INFO

      EnvironmentParser.parse(@log)
    end

    no_tasks do
      # Build a Moonshot::Controller from the CLI options.
      def controller # rubocop:disable AbcSize
        controller = Moonshot::Controller.new

        # Apply CLI options to configuration defined by Moonfile.
        controller.config                  = Moonshot.config
        controller.config.environment_name = options[:name]
        controller.config.logger           = @log

        # Degrade to a more compatible logger if the terminal seems outdated,
        # or at the users request.
        if !$stdout.isatty || !options[:interactive_logger]
          controller.config.interactive_logger = InteractiveLoggerProxy.new(@log)
        end

        controller.config.show_all_stack_events = true if options[:show_all_events]
        controller.config.parent_stacks = [options[:parent]] if options[:parent]

        controller
      rescue => e
        raise Thor::Error, e.message
      end
    end

    desc :list, 'List stacks for this application.'
    def list
      controller.list
    end

    desc :create, 'Create a new environment.'
    option(
      :parent,
      type: :string,
      aliases: '-p',
      desc: 'Parent stack to import parameters from.')
    option :deploy, default: true, type: :boolean, aliases: '-d',
                    desc: 'Choose if code should be deployed after stack is created'
    option :show_all_events, desc: 'Show all stack events during update. (Default: errors only)'
    def create
      controller.create
      controller.deploy_code if options[:deploy]
    end

    desc :update, 'Update the CloudFormation stack within an environment.'
    option :show_all_events, desc: 'Show all stack events during update. (Default: errors only)'
    def update
      controller.update
    end

    desc :status, 'Get the status of an existing environment.'
    def status
      controller.status
    end

    desc 'deploy-code', 'Create a build from the working directory, and deploy it.' # rubocop:disable LineLength
    def deploy_code
      controller.deploy_code
    end

    desc 'build-version VERSION', 'Build a tarball of the software, ready for deployment.' # rubocop:disable LineLength
    def build_version(version_name)
      controller.build_version(version_name)
    end

    desc 'deploy-version VERSION_NAME', 'Deploy a versioned release to both EB environments in an environment.' # rubocop:disable LineLength
    def deploy_version(version_name)
      controller.deploy_version(version_name)
    end

    desc :delete, 'Delete an existing environment.'
    option :show_all_events, desc: 'Show all stack events during update. (Default: errors only)'
    def delete
      controller.delete
    end

    desc :doctor, 'Run configuration checks against current environment.'
    def doctor
      success = controller.doctor
      raise Thor::Error, 'One or more checks failed.' unless success
    end
  end
end
