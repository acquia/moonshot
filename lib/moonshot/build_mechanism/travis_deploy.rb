# frozen_string_literal: true

require 'moonshot/shell'
require 'travis'
require 'travis/pro'
require 'travis/client/auto_login'

module Moonshot::BuildMechanism
  # This simply waits for Travis-CI to finish building a job matching the
  # version and 'BUILD=1'.
  class TravisDeploy
    include Moonshot::ResourcesHelper
    include Moonshot::DoctorHelper
    include Moonshot::Shell

    MAX_BUILD_FIND_ATTEMPTS = 10

    attr_reader :output_file

    def initialize(slug, pro: false, timeout: 900)
      @slug = slug
      @pro = pro
      @timeout = timeout

      @endpoint = pro ? '--pro' : '--org'
      @travis_base = @pro ? Travis::Pro : Travis
      @cli_args = "-r #{@slug} #{@endpoint}"
    end

    def pre_build_hook(_); end

    def build_hook(version)
      job_number = find_build_and_job(version)
      wait_for_job(job_number)
      check_build(version)
    end

    def post_build_hook(_); end

    private

    # Authenticates with the proper travis service.
    def authenticate
      Travis::Client::AutoLogin.new(@travis_base).authenticate
    end

    # Retrieves the travis repository.
    #
    # @return [Travis::Client::Repository]
    def repo
      @repo ||= @travis_base::Repository.find(@slug)
    end

    def find_build_and_job(version)
      job_number = nil
      ilog.start_threaded('Find Travis CI build') do |step|
        job_number = wait_for_build(version)

        step.success("Travis CI ##{job_number.gsub(/\..*/, '')} running.")
      end
      job_number
    end

    # Looks for the travis build and attempts to retry if the build does not
    # exist yet.
    #
    # @param verison [String] Build version to look for.
    #
    # @return [String] Job number for the travis build.
    def wait_for_build(version)
      # Attempt to find the build. Re-attempt if the build can not
      # be found on travis yet.
      retry_opts = {
        tries: MAX_BUILD_FIND_ATTEMPTS,
        base_interval: 10
      }
      job_number = nil
      sh_retry("bundle exec travis show #{@cli_args} #{version}",
               opts: retry_opts) do |build_out|
        raise CommandError, "Build for #{version} not found.\n#{build_out}" \
          unless (job_number = build_out.match(/^#(\d+\.\d+) .+BUILD=1.+/)[1])
      end
      job_number
    end

    # Waits for a job to complete, within the defined timeout.
    #
    # @param job_number [String] The job number to wait for.
    def wait_for_job(job_number)
      authenticate

      # Wait for the job to complete or hit the timeout.
      start = Time.new
      job = repo.job(job_number)
      ilog.start_threaded("Waiting for job #{job_number} to complete.") do |s|
        while !job.finished? && Time.new - start < @timeout
          s.continue("Job status: #{job.state}")
          sleep 10
          job.reload
        end

        if job.finished?
          s.success
        else
          s.failure("Job #{job_number} did not complete within time limit of " \
                    "#{@timeout} seconds")
        end
      end
    end

    def check_build(version)
      cmd = "bundle exec travis show #{@cli_args} #{version}"
      sh_step(cmd) do |step, out|
        raise "Build didn't pass.\n#{out}" \
          if out =~ /^#(\d+\.\d+) (?!passed).+BUILD=1.+/

        step.success("Travis CI build for #{version} passed.")
      end
    end

    def doctor_check_travis_auth
      sh_out("bundle exec travis raw #{@endpoint} repos/#{@slug}")
    rescue StandardError => e
      critical "`travis` not available or not authorized.\n#{e.message}"
    else
      success '`travis` installed and authorized.'
    end
  end
end
