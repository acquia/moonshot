require_relative 'default_strategy'
require_relative 'ssh_config'
require_relative 'task'

module Moonshot
  # Holds configuration for Moonshot::Controller
  class ControllerConfig
    attr_accessor :additional_tag
    attr_accessor :app_name
    attr_accessor :artifact_repository
    attr_accessor :build_mechanism
    attr_accessor :deployment_mechanism
    attr_accessor :environment_name
    attr_accessor :interactive_logger
    attr_accessor :parent_stacks
    attr_accessor :plugins
    attr_accessor :show_all_stack_events
    attr_accessor :parameter_strategy
    attr_accessor :ssh_config
    attr_accessor :ssh_command
    attr_accessor :ssh_auto_scaling_group_name
    attr_accessor :ssh_instance
    attr_accessor :project_root

    def initialize
      @interactive_logger    = InteractiveLogger.new
      @parameter_strategy    = Moonshot::ParameterStrategy::DefaultStrategy.new
      @parent_stacks         = []
      @plugins               = []
      @project_root          = Dir.pwd
      @show_all_stack_events = false
      @ssh_config            = SSHConfig.new

      user = ENV.fetch('USER', 'default-user').gsub(/\W/, '')
      @environment_name = "dev-#{user}"
    end
  end
end
