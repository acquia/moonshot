require_relative 'default_strategy'
require_relative 'ssh_config'
require_relative 'task'
require_relative 'ask_user_source'

module Moonshot
  # Holds configuration for Moonshot::Controller
  class ControllerConfig
    attr_accessor :additional_tag
    attr_accessor :answer_file
    attr_accessor :app_name
    attr_accessor :artifact_repository
    attr_accessor :build_mechanism
    attr_accessor :deployment_mechanism
    attr_accessor :dev_build_name_proc
    attr_accessor :environment_name
    attr_accessor :interactive
    attr_accessor :interactive_logger
    attr_accessor :parameter_overrides
    attr_accessor :parameters
    attr_accessor :parent_stacks
    attr_accessor :default_parameter_source
    attr_accessor :parameter_sources
    attr_accessor :plugins
    attr_accessor :project_root
    attr_accessor :show_all_stack_events
    attr_accessor :ssh_auto_scaling_group_name
    attr_accessor :ssh_command
    attr_accessor :ssh_config
    attr_accessor :ssh_instance

    def initialize
      @default_parameter_source = AskUserSource.new
      @interactive              = true
      @interactive_logger       = InteractiveLogger.new
      @parameter_overrides      = {}
      @parameter_sources        = {}
      @parameters               = ParameterCollection.new
      @parent_stacks            = []
      @plugins                  = []
      @project_root             = Dir.pwd
      @show_all_stack_events    = false
      @ssh_config               = SSHConfig.new

      @dev_build_name_proc = lambda do |c|
        ['dev', c.app_name, c.environment_name, Time.now.to_i].join('/')
      end

      user = ENV.fetch('USER', 'default-user').gsub(/\W/, '')
      @environment_name = "dev-#{user}"
    end
  end
end
