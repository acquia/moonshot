require 'interactive-logger'
require_relative 'default_strategy'
require_relative 'merge_strategy'

# Base class for Moonshot-powered project tooling.
module Moonshot
  # The main entry point for Moonshot, this class should be extended by
  # project tooling.
  class CLI < Thor # rubocop:disable ClassLength
    class_option(:name, aliases: 'n', default: nil, type: :string)
    class_option(:interactive_logger, type: :boolean, default: true)
    class_option(:verbose, aliases: 'v', type: :boolean)

    class << self
      attr_accessor :application_name
      attr_accessor :artifact_repository
      attr_accessor :auto_prefix_stack
      attr_accessor :build_mechanism
      attr_accessor :deployment_mechanism
      attr_accessor :default_parent_stack
      attr_accessor :default_parameter_strategy
      attr_reader :plugins

      def plugin(plugin)
        @plugins ||= []
        @plugins << plugin
      end

      def parent(value)
        @default_parent_stack = value
      end

      def parameter_strategy(strategy)
        @default_parameter_strategy = strategy
      end

      def check_class_configuration
        raise Thor::Error, 'No application_name is set!' unless application_name
      end

      def exit_on_failure?
        true
      end

      def inherited(base)
        base.include(Moonshot::ArtifactRepository)
        base.include(Moonshot::BuildMechanism)
        base.include(Moonshot::DeploymentMechanism)
      end

      def ssh_options!
        option :user, default: ENV['MOONSHOT_SSH_USER'] || ENV['USER'], type: :string,
                      aliases: '-l',
                      desc: 'Specifies the user to log in as on the remote machine.'
        option :identity_file, default: ENV['MOONSHOT_SSH_KEY_FILE'], type: :string,
                               aliases: '-i',
                               desc: 'Selects a file from which the identity (private key) for '\
                                     'public key authentication is read.'
        option :instance, default: nil, type: :string, aliases: '-s',
                          desc: 'Connect to specified instance ID instead of the first one.'
        option :command, default: nil, type: :string, aliases: '-c',
                         desc: 'Execute the specified command instead of opening a shell.'
        option :auto_scaling_group, default: nil, type: :string, aliases: '-g',
                                    desc: 'The logical ID of the auto scaling group to SSH into. '\
                                    'Mandatory if the stack has multiple ASGs, '\
                                    'ignored if you have only one.'
      end
    end

    def initialize(*args)
      super
      @log = Logger.new(STDOUT)
      @log.formatter = proc do |s, d, _, msg|
        "[#{self.class.name} #{s} #{d.strftime('%T')}] #{msg}\n"
      end
      @log.level = options[:verbose] ? Logger::DEBUG : Logger::INFO

      self.class.check_class_configuration
    end

    no_tasks do
      # Build a Moonshot::Controller from the CLI options.
      def controller # rubocop:disable AbcSize, CyclomaticComplexity, PerceivedComplexity
        Moonshot::Controller.new do |config|
          config.app_name             = self.class.application_name
          config.artifact_repository  = self.class.artifact_repository
          config.auto_prefix_stack    = self.class.auto_prefix_stack
          config.build_mechanism      = self.class.build_mechanism
          config.deployment_mechanism = self.class.deployment_mechanism
          config.environment_name     = options[:name]
          config.logger               = @log

          # Degrade to a more compatible logger if the terminal seems outdated,
          # or at the users request.
          if !$stdout.isatty || !options[:interactive_logger]
            config.interactive_logger = InteractiveLoggerProxy.new(@log)
          end

          config.show_all_stack_events = true if options[:show_all_events]
          config.plugins = self.class.plugins if self.class.plugins

          if options[:parent]
            config.parent_stacks << options[:parent]
          elsif self.class.default_parent_stack
            config.parent_stacks << self.class.default_parent_stack
          end

          parameter_strategy = options[:parameter_strategy] || self.class.default_parameter_strategy
          config.parameter_strategy = parameter_strategy_factory(parameter_strategy) \
            unless parameter_strategy.nil?

          config.ssh_config.ssh_user = options[:user]
          config.ssh_config.ssh_identity_file = options[:identity_file]
          config.ssh_instance = options[:instance]
          config.ssh_command = options[:command]
          config.ssh_auto_scaling_group_name = options[:auto_scaling_group]
        end
      rescue => e
        raise Thor::Error, e.message
      end

      def parameter_strategy_factory(value)
        case value.to_sym
        when :default
          Moonshot::ParameterStrategy::DefaultStrategy.new
        when :merge
          Moonshot::ParameterStrategy::MergeStrategy.new
        else
          raise Thor::Error, "Unknown parameter strategy: #{value}"
        end
      end

      def ssh_command(command)
        arguments = ARGV.drop(1)
        arguments += ['--command', command]
        invoke :ssh, [], arguments
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
      desc: "Parent stack to import parameters from. (Default: #{default_parent_stack || 'None'})")
    option :deploy, default: true, type: :boolean, aliases: '-d',
                    desc: 'Choose if code should be deployed after stack is created'
    option :version, default: nil, type: :string,
                     desc: 'Version to deploy. Only valid if deploy flag is set.'
    option :show_all_events, desc: 'Show all stack events during update. (Default: errors only)'
    def create
      controller.create

      if options[:deploy]
        if options[:version].nil?
          controller.deploy_code
        else
          controller.deploy_version(options[:version])
        end
      end
    end

    desc :update, 'Update the CloudFormation stack within an environment.'
    option(
      :parameter_strategy,
      type: :string,
      desc: 'Override default parameter strategy.')
    option(
      :show_all_events,
      type: :boolean,
      desc: 'Show all stack events during update. (Default: errors only)')
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

    desc :ssh, 'SSH into the first or specified instance on the stack.'
    ssh_options!
    def ssh
      controller.ssh
    end
  end
end
