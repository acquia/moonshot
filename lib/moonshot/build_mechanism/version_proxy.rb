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

  def doctor_hook(options = {})
    @release.doctor_hook(options)
    @dev.doctor_hook(options)
  end

  def resources=(r)
    super
    @release.resources = r
    @dev.resources = r
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
