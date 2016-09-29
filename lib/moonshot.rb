require 'English'
require 'aws-sdk'
require 'logger'
require 'thor'

module Moonshot
  module ArtifactRepository # rubocop:disable Documentation
  end
  module BuildMechanism # rubocop:disable Documentation
  end
  module DeploymentMechanism # rubocop:disable Documentation
  end
  module Plugins # rubocop:disable Documentation
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
  'controller',
  'controller_config',
  'cli',
  'stack',
  'stack_config',
  'stack_lister',
  'stack_events_poller',

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
