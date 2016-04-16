require 'forwardable'
require 'moonshot/shell'
require 'open3'
require 'semantic'
require 'shellwords'
require 'tempfile'
require 'vandamme'

module Moonshot::BuildMechanism
  # A build mechanism that creates a tag and GitHub release.
  class GithubRelease # rubocop:disable Metrics/ClassLength
    extend Forwardable
    include Moonshot::ResourcesHelper
    include Moonshot::DoctorHelper
    include Moonshot::Shell

    def_delegator :@build_mechanism, :output_file

    # @param build_mechanism Delegates building after GitHub release is created.
    def initialize(build_mechanism)
      @build_mechanism = build_mechanism
    end

    def doctor_hook
      super
      @build_mechanism.doctor_hook
    end

    def resources=(r)
      super
      @build_mechanism.resources = r
    end

    def pre_build_hook(version)
      @semver = ::Semantic::Version.new(version)
      @target_version = [@semver.major, @semver.minor, @semver.patch].join('.')
      sh_step('git fetch --tags upstream')
      @sha = `git rev-parse HEAD`.chomp
      validate_commit
      @changes = validate_changelog(@target_version)
      confirm_or_fail(@semver)
      @build_mechanism.pre_build_hook(version)
    end

    def build_hook(version)
      assert_state(version)
      git_tag(version, @sha, @changes)
      git_push_tag('upstream', version)
      hub_create_release(@semver, @sha, @changes)
      ilog.msg("#{releases_url}/tag/#{version}")
      @build_mechanism.build_hook(version)
    end

    def post_build_hook(version)
      assert_state(version)
      @build_mechanism.post_build_hook(version)
    end

    private

    # We carry state between hooks, make sure that's still valid.
    def assert_state(version)
      raise "#{version} != #{@semver}" unless version == @semver.to_s
    end

    def confirm_or_fail(version)
      say("\nCommit Summary", :yellow)
      say("#{@commit_detail}\n")
      say('Commit CI Status', :yellow)
      say("#{@ci_statuses}\n")
      say("Changelog for #{version}", :yellow)
      say("#{@changes}\n\n")

      q = "Do you want to tag and release this commit as #{version}? [y/n]"
      raise 'Release declined.' unless yes?(q)
    end

    def git_tag(tag, sha, annotation)
      return if git_tag_exists(tag, sha)

      cmd = "git tag -a #{tag} #{sha} --file=-"
      sh_step(cmd, stdin: annotation)
    end

    # Determines if a valid git tag already exists.
    #
    # @param tag [String] Tag to check existence for.
    # @param sha [String] SHA to verify the tag against.
    #
    # @return [Boolean] Whether or not the tag exists.
    #
    # @raise [RuntimeError] if the SHAs do not match.
    def git_tag_exists(tag, sha)
      exists = false
      sh_step("git tag -l #{tag}") do |_, output|
        exists = (output.strip == tag)
      end

      # If the tag does exist, make sure the existing SHA matches the SHA we're
      # trying to build from.
      if exists
        sh_step("git rev-list -n 1 #{tag}") do |_, output|
          raise "#{tag} already exists at a different SHA" \
            if output.strip != sha
        end

        log.info("tag #{tag} already exists")
      end

      exists
    end

    def git_push_tag(remote, tag)
      cmd = "git push #{remote} refs/tags/#{tag}:refs/tags/#{tag}"
      sh_step(cmd) do
        sleep 2 # GitHub needs a moment to register the tag.
      end
    end

    def hub_create_release(semver, commitish, changelog_entry)
      return if hub_release_exists(semver)

      message = "#{semver}\n\n#{changelog_entry}"
      cmd = "hub release create #{semver} --commitish=#{commitish}"
      cmd << ' --prerelease' if semver.pre || semver.build
      cmd << " --message=#{Shellwords.escape(message)}"
      sh_step(cmd)
    end

    # Determines if a github release already exists.
    #
    # @param semver [String] Semantic version string for the release.
    #
    # @return [Boolean]
    def hub_release_exists(semver)
      sh_step("hub release show #{semver}")
      log.info("release #{semver} already exists")
      true
    rescue RuntimeError
      false
    end

    def validate_commit
      cmd = "git show --stat #{@sha}"
      sh_step(cmd, msg: "Validate commit #{@sha}.") do |_, out|
        @commit_detail = out
      end
      cmd = "hub ci-status --verbose #{@sha}"
      sh_step(cmd, msg: "Check CI status for #{@sha}.") do |_, out|
        @ci_statuses = out
      end
    end

    def validate_changelog(version)
      changes = nil
      ilog.start_threaded('Validate `CHANGELOG.md`.') do |step|
        changes = fetch_changes(version)
        step.success
      end
      changes
    end

    def fetch_changes(version)
      parser = Vandamme::Parser.new(
        changelog: File.read('CHANGELOG.md'),
        format: 'markdown'
      )
      parser.parse.fetch(version) do
        raise "#{version} not found in CHANGELOG.md"
      end
    end

    def releases_url
      `hub browse -u -- releases`.chomp
    end

    def doctor_check_upstream
      sh_out('git remote | grep ^upstream$')
    rescue => e
      critical "git remote `upstream` not found.\n#{e.message}"
    else
      success 'git remote `upstream` exists.'
    end

    def doctor_check_hub_auth
      sh_out('hub ci-status 0.0.0')
    rescue => e
      critical "`hub` failed, install hub and authorize it.\n#{e.message}"
    else
      success '`hub` installed and authorized.'
    end
  end
end
