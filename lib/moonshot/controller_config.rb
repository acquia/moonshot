require_relative 'default_strategy'
require_relative 'ssh_config'

module Moonshot
  # Holds configuration for Moonshot::Controller
  class ControllerConfig
    attr_accessor :app_name
    attr_accessor :artifact_repository
    attr_accessor :auto_prefix_stack
    attr_accessor :build_mechanism
    attr_accessor :deployment_mechanism
    attr_accessor :environment_name
    attr_accessor :interactive_logger
    attr_accessor :logger
    attr_accessor :parent_stacks
    attr_accessor :plugins
    attr_accessor :show_all_stack_events
    attr_accessor :parameter_strategy
    attr_accessor :ssh_config
    attr_accessor :ssh_command
    attr_accessor :ssh_auto_scaling_group_name
    attr_accessor :ssh_instance

    def initialize
      @auto_prefix_stack = true
      @interactive_logger = InteractiveLogger.new
      @logger = Logger.new(STDOUT)
      @parent_stacks = []
      @plugins = []
      @show_all_stack_events = false
      @parameter_strategy = Moonshot::ParameterStrategy::DefaultStrategy.new
      @ssh_config = SSHConfig.new
    end
  end
end
