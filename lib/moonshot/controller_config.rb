# frozen_string_literal: true

module Moonshot
  # Holds configuration for Moonshot::Controller
  class ControllerConfig
    attr_reader :account_alias

    attr_accessor :additional_tag, :answer_file, :app_name, :artifact_repository, :build_mechanism,
                  :changeset_wait_time, :deployment_mechanism, :dev_build_name_proc, :environment_name,
                  :interactive, :interactive_logger, :parameter_overrides, :parameters, :parent_stacks,
                  :default_parameter_source, :parameter_sources, :plugins, :project_root,
                  :show_all_stack_events, :ssh_auto_scaling_group_name, :ssh_command, :ssh_config,
                  :ssh_instance, :template_file, :template_s3_bucket

    def initialize
      @default_parameter_source = AskUserSource.new
      @interactive              = true
      @interactive_logger       = InteractiveLogger.new
      @parameter_overrides      = {}
      @parameter_sources        = {}
      @parameters               = ParameterCollection.new
      @parent_stacks            = []
      @account_alias            = nil
      @per_account_config       = {}
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

    def in_account(name, &blk)
      # Store account specific configs as lambdas, to be evaluated
      # if the account name matches during controller execution.
      @per_account_config[name] = blk
    end

    def update_for_account!
      # Evaluated any account-specific configuration.
      @account_alias = Moonshot::AccountContext.get
      return unless @account_alias
      return unless @per_account_config.key?(@account_alias)

      @per_account_config[@account_alias].call(self)
    end
  end
end
