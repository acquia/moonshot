require_relative 'ssh_target_selector'
require_relative 'ssh_command_builder'

module Moonshot
  # The Controller coordinates and performs all Moonshot actions.
  class Controller
    attr_accessor :config

    def initialize
      @config = ControllerConfig.new
      yield @config if block_given?
    end

    def list
      Moonshot::StackLister.new(@config.app_name).list
    end

    def create
      run_plugins(:pre_create)
      run_hook(:deploy, :pre_create)
      stack_ok = stack.create
      if stack_ok # rubocop:disable GuardClause
        run_hook(:deploy, :post_create)
        run_plugins(:post_create)
      end
    end

    def update
      run_plugins(:pre_update)
      run_hook(:deploy, :pre_update)
      stack.update
      run_hook(:deploy, :post_update)
      run_plugins(:post_update)
    end

    def status
      run_plugins(:pre_status)
      run_hook(:deploy, :status)
      stack.status
      run_plugins(:post_status)
    end

    def deploy_code
      version = "#{stack_name}-#{Time.now.to_i}"
      build_version(version)
      deploy_version(version)
    end

    def build_version(version_name)
      run_plugins(:pre_build)
      run_hook(:build, :pre_build, version_name)
      run_hook(:build, :build, version_name)
      run_hook(:build, :post_build, version_name)
      run_plugins(:post_build)
      run_hook(:repo, :store, @config.build_mechanism, version_name)
    end

    def deploy_version(version_name)
      run_plugins(:pre_deploy)
      run_hook(:deploy, :deploy, @config.artifact_repository, version_name)
      run_plugins(:post_deploy)
    end

    def delete
      run_plugins(:pre_delete)
      run_hook(:deploy, :pre_delete)
      stack.delete
      run_hook(:deploy, :post_delete)
      run_plugins(:post_delete)
    end

    def doctor
      # @todo use #run_hook when Stack becomes an InfrastructureProvider
      success = true
      success &&= stack.doctor_hook
      success &&= run_hook(:build, :doctor)
      success &&= run_hook(:repo, :doctor)
      success &&= run_hook(:deploy, :doctor)
      results = run_plugins(:doctor)

      success = false if results.value?(false)
      success
    end

    def ssh
      run_plugins(:pre_ssh)
      @config.ssh_instance ||= SSHTargetSelector.new(
        stack, asg_name: @config.ssh_auto_scaling_group_name).choose!
      cb = SSHCommandBuilder.new(@config.ssh_config, @config.ssh_instance)
      result = cb.build(@config.ssh_command)

      warn "Opening SSH connection to #{@config.ssh_instance} (#{result.ip})..."
      exec(result.cmd)
    end

    def stack
      @stack ||= Stack.new(@config)
    end

    private

    def resources
      @resources ||=
        Resources.new(stack: stack, ilog: @config.interactive_logger)
    end

    def run_hook(type, name, *args)
      mech = get_mechanism(type)
      name = name.to_s << '_hook'

      return unless mech && mech.respond_to?(name)

      mech.resources = resources
      mech.send(name, *args)
    end

    def run_plugins(type)
      results = {}
      @config.plugins.each do |plugin|
        next unless plugin.respond_to?(type)
        results[plugin] = plugin.send(type, resources)
      end

      results
    end

    def get_mechanism(type)
      case type
      when :build then @config.build_mechanism
      when :repo then @config.artifact_repository
      when :deploy then @config.deployment_mechanism
      else
        raise "Unknown hook type: #{type}"
      end
    end
  end
end
