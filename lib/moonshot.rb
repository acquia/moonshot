require 'English'
require 'aws-sdk'
require 'logger'
require 'thor'
require 'interactive-logger'

module Moonshot
  def self.config
    @config ||= Moonshot::ControllerConfig.new
    block_given? ? yield(@config) : @config
  end

  module ArtifactRepository
  end
  module BuildMechanism
  end
  module DeploymentMechanism
  end
  module Plugins
  end
end

[
  # Helpers
  'creds_helper',
  'doctor_helper',
  'resources',
  'resources_helper',

  # Core
  'interactive_logger_proxy',
  'command_line',
  'command',
  'ssh_command',
  'commands/build',
  'commands/console',
  'commands/create',
  'commands/delete',
  'commands/deploy',
  'commands/doctor',
  'commands/list',
  'commands/push',
  'commands/ssh',
  'commands/status',
  'commands/update',
  'controller',
  'controller_config',
  'stack',
  'stack_config',
  'stack_lister',
  'stack_events_poller',
  'merge_strategy',
  'default_strategy',

  # Built-in mechanisms
  'artifact_repository/s3_bucket',
  'artifact_repository/s3_bucket_via_github_releases',
  'build_mechanism/script',
  'build_mechanism/github_release',
  'build_mechanism/travis_deploy',
  'build_mechanism/version_proxy',
  'deployment_mechanism/code_deploy',

  # Core Tools
  'tools/asg_rollout'
].each { |f| require_relative "moonshot/#{f}" }

# Bundled plugins
[
  'backup'
].each { |p| require_relative "plugins/#{p}" }
