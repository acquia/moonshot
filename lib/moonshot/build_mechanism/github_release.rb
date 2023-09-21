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
    def initialize(build_mechanism,
                   ci_status_timeout: 600,
                   max_tag_find_timeout: 240,
                   skip_ci_status: false)
      @build_mechanism = build_mechanism
      @ci_status_timeout = ci_status_timeout
      @max_tag_find_timeout = max_tag_find_timeout
      @skip_ci_status = skip_ci_status
    end

    def build_cli_hook(parser)
      parser.on('-s', '--[no-]skip-ci-status', 'Skips checks on CI jobs', TrueClass) do |value|
        @skip_ci_status = value
      end

      parser
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

      return unless Moonshot.config.interactive

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
        hub_find_remote_tag(tag)
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
      exists = false
      sh_step("hub release show #{semver}", fail: false) do |_, output|
        first_line = output.split("\n").first
        exists = !first_line.nil? && first_line.strip == semver.to_s
      end
      log.info("release #{semver} already exists") if exists
      exists
    end

    # Attempt to find the build. Rescue and re-attempt if the build can not
    # be found on github yet.
    def hub_find_remote_tag(tag_name)
      retry_opts = {
        max_elapsed_time: @max_tag_find_timeout,
        multiplier: 2
      }
      sh_retry("hub ls-remote --exit-code --tags upstream #{tag_name}",
               opts: retry_opts)
    end

    def validate_commit
      cmd = "git show --stat #{@sha}"
      sh_step(cmd, msg: "Validate commit #{@sha}.") do |_, out|
        @commit_detail = out
      end
      @ci_statuses = check_ci_status(@sha) if @skip_ci_status == false
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

    # Checks for the commit's CI job status. If its not finished yet,
    # wait till timeout.
    #
    # @param sha [String] Commit sha.
    #
    # @return [String] Status and links to the CI jobs
    def check_ci_status(sha)
      out = nil
      retry_opts = {
        max_elapsed_time: @ci_status_timeout,
        base_interval: 10
      }
      ilog.start_threaded("Check CI status for #{sha}.") do |step|
        out = sh_retry("hub ci-status --verbose #{sha}", opts: retry_opts)
        step.success
      end
      out
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
      sh_out('hub ci-status master')
    rescue => e
      critical "`hub` failed, install hub and authorize it.\n#{e.message}"
    else
      success '`hub` installed and authorized.'
    end
  end
end
