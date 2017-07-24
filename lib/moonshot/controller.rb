module Moonshot
  # The Controller coordinates and performs all Moonshot actions.
  class Controller # rubocop:disable ClassLength
    attr_accessor :config

    def initialize(config)
      @config = config
    end

    def list
      Moonshot::StackLister.new(@config.app_name).list
    end

    def create # rubocop:disable AbcSize
      # Scan the template for all required parameters and configure
      # the ParameterCollection.
      @config.parameters = ParameterCollection.from_template(stack.template)

      # Import all Outputs from parent stacks as Parameters on this
      # stack.
      ParentStackParameterLoader.new(@config).load!

      # If there is an answer file, use it to populate parameters.
      if @config.answer_file
        YAML.load_file(@config.answer_file).each do |key, value|
          @config.parameters[key] = value
        end
      end

      # Apply any overrides configured, such as from the CLI -p option.
      @config.parameter_overrides.each do |key, value|
        @config.parameters[key] = value
      end

      # Interview the user for missing parameters, using the
      # appropriate prompts.
      @config.parameters.values.each do |sp|
        next if sp.set?

        parameter_source = @config.parameter_sources.fetch(sp.name,
                                                           @config.default_parameter_source)
        parameter_source.get(sp)
      end

      # Plugins get the final say on parameters before create,
      # allowing them to manipulate user supplied input and answers
      # file content.
      run_plugins(:pre_create)

      # Fail if any parameters are still missing without defaults.
      missing_parameters = @config.parameters.missing_for_create
      unless missing_parameters.empty?
        raise "The following parameters were not provided: #{missing_parameters.map(&:name).join(', ')}" # rubocop:disable LineLength
      end

      run_hook(:deploy, :pre_create)
      stack_ok = stack.create
      if stack_ok # rubocop:disable GuardClause
        run_hook(:deploy, :post_create)
        run_plugins(:post_create)
      else
        raise 'Stack creation failed!'
      end
    end

    def update(dry_run:, force:, refresh_parameters:) # rubocop:disable AbcSize
      # Scan the template for all required parameters and configure
      # the ParameterCollection.
      @config.parameters = ParameterCollection.from_template(stack.template)

      # Set all values already provided by the stack to UsePreviousValue.
      stack.parameters.each do |key, value|
        @config.parameters[key].use_previous!(value) if @config.parameters.key?(key)
      end

      # Import all Outputs from parent stacks as Parameters on this
      # stack.
      parent_stack_params = ParentStackParameterLoader.new(@config)
      refresh_parameters ? parent_stack_params.load! : parent_stack_params.load_missing_only!

      # If there is an answer file, use it to populate parameters.
      if @config.answer_file
        YAML.load_file(@config.answer_file).each do |key, value|
          @config.parameters[key] = value
        end
      end

      # Apply any overrides configured, such as from the CLI -p option.
      @config.parameter_overrides.each do |key, value|
        @config.parameters[key] = value
      end

      # Interview the user for missing parameters, using the
      # appropriate prompts.
      @config.parameters.values.reject(&:set?).each do |sp|
        parameter_source = @config.parameter_sources.fetch(sp.name,
                                                           @config.default_parameter_source)
        parameter_source.get(sp)
      end

      # Plugins get the final say on parameters before create,
      # allowing them to manipulate user supplied input and answers
      # file content.
      run_plugins(:pre_update)

      # Fail if any parameters are still missing without defaults.
      missing_parameters = @config.parameters.missing_for_update
      unless missing_parameters.empty?
        raise "The following parameters were not provided: #{missing_parameters.map(&:name).join(', ')}" # rubocop:disable LineLength
      end

      run_hook(:deploy, :pre_update)
      stack.update(dry_run: dry_run, force: force)
      run_hook(:deploy, :post_update)
      run_plugins(:post_update)
    end

    def status
      run_plugins(:pre_status)
      run_hook(:deploy, :status)
      stack.status
      run_plugins(:post_status)
    end

    def push
      version = @config.dev_build_name_proc.call(@config)
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
      # Populate the current values of parameters, for use by plugins.
      @config.parameters = ParameterCollection.from_template(stack.template)
      stack.parameters.each do |key, value|
        @config.parameters[key].use_previous!(value) if @config.parameters.key?(key)
      end

      run_plugins(:pre_delete)
      run_hook(:deploy, :pre_delete)
      stack_ok = stack.delete
      if stack_ok # rubocop:disable GuardClause
        run_hook(:deploy, :post_delete)
        run_plugins(:post_delete)
      else
        raise 'Stack deletion failed!'
      end
    end

    def doctor
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
        Resources.new(stack: stack, ilog: @config.interactive_logger, controller: self)
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
