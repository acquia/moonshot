# frozen_string_literal: true

require 'forwardable'
require 'semantic'

# This proxies build request do different mechanisms. One for semver compliant
# releases and another for everything else.
class Moonshot::BuildMechanism::VersionProxy
  extend Forwardable
  include Moonshot::ResourcesHelper

  def_delegator :@active, :output_file

  def initialize(release:, dev:)
    @release = release
    @dev = dev
  end

  def doctor_hook
    @release.doctor_hook
    @dev.doctor_hook
  end

  def resources=(res)
    super
    @release.resources = res
    @dev.resources = res
  end

  def pre_build_hook(version)
    active(version).pre_build_hook(version)
  end

  def build_hook(version)
    active(version).build_hook(version)
  end

  def post_build_hook(version)
    active(version).post_build_hook(version)
  end

  def build_cli_hook(parser)
    # Expose any command line arguments provided by the build mechanisms. We
    # don't know the version at this point, so we can't call the hook on only
    # the one we're going to use, which may result in options being exposed that
    # are only applicable for one of the build mechanisms.
    parser = @release.build_cli_hook(parser) if @release.respond_to?(:build_cli_hook)
    parser = @dev.build_cli_hook(parser) if @dev.respond_to?(:build_cli_hook)

    parser
  end

  private

  def active(version)
    @active = if release?(version)
                @release
              else
                @dev
              end
  end

  def release?(version)
    ::Semantic::Version.new(version)
  rescue ArgumentError
    false
  end
end
