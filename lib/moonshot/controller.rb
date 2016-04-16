module Moonshot
  # The Controller coordinates and performs all Moonshot actions.
  class Controller # rubocop:disable ClassLength
    attr_accessor :config

    def initialize
      @config = ControllerConfig.new
      yield @config if block_given?
    end

    def list
      Moonshot::StackLister.new(
        @config.app_name, log: @config.logger).list
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
      run_plugins(:status)
      run_hook(:deploy, :status)
      stack.status
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

    def stack
      @stack ||= Stack.new(stack_name,
                           app_name: @config.app_name,
                           log: @config.logger,
                           ilog: @config.interactive_logger) do |config|
        config.parent_stacks = @config.parent_stacks
        config.show_all_events = @config.show_all_stack_events
      end
    end

    private

    def default_stack_name
      user = ENV.fetch('USER').gsub(/\W/, '')
      "#{@config.app_name}-dev-#{user}"
    end

    def ensure_prefix(name)
      if name.start_with?(@config.app_name + '-')
        name
      else
        @config.app_name + "-#{name}"
      end
    end

    def stack_name
      name = @config.environment_name || default_stack_name
      if @config.auto_prefix_stack == false
        name
      else
        ensure_prefix(name)
      end
    end

    def resources
      @resources ||=
        Resources.new(stack: stack, log: @config.logger,
                      ilog: @config.interactive_logger)
    end

    def run_hook(type, name, *args)
      mech = get_mechanism(type)
      name = name.to_s << '_hook'

      @config.logger.debug("Calling hook=#{name} on mech=#{mech.class}")
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
