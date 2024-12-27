# frozen_string_literal: true

require 'moonshot/artifact_repository/s3_bucket'
require 'moonshot/shell'
require 'digest'
require 'securerandom'
require 'semantic'
require 'tmpdir'
require 'retriable'

module Moonshot::ArtifactRepository
  # S3 Bucket repository backed by GitHub releases.
  # If a SemVer package isn't found in S3, it is copied from GitHub releases.
  class S3BucketViaGithubReleases < S3Bucket # rubocop:disable Metrics/ClassLength
    include Moonshot::BuildMechanism
    include Moonshot::Shell

    # @override
    # If release version, transfer from GitHub to S3.
    def store_hook(build_mechanism, version)
      if release?(version)
        if (@output_file = build_mechanism.output_file)
          attach_release_asset(version, @output_file)
          # Upload to s3.
          super
        else
          # If there is no output file, assume it's on GitHub already.
          transfer_release_asset_to_s3(version)
        end
      else
        super
      end
    end

    # @override
    # If release version, transfer from GitHub to S3.
    # @todo This is a super hacky place to handle the transfer, give
    # artifact repositories a hook before deploy.
    def filename_for_version(version)
      s3_name = super
      github_to_s3(version, s3_name) if !@output_file && release?(version) && !in_s3?(s3_name)
      s3_name
    end

    private

    def release?(version)
      ::Semantic::Version.new(version)
    rescue ArgumentError
      false
    end

    def in_s3?(key)
      s3_client.head_object(key:, bucket: bucket_name)
    rescue ::Aws::S3::Errors::NotFound
      false
    end

    def attach_release_asset(version, file)
      # -m '' leaves message unchanged.
      cmd = "hub release edit #{version} -m '' --attach=#{file}"

      # If there is a checksum file, attach it as well. We only support MD5
      # since that's what S3 uses.
      checksum_file = "#{File.basename(file, '.tar.gz')}.md5"
      cmd += " --attach=#{checksum_file}" if File.exist?(checksum_file)

      sh_step(cmd)
    end

    def transfer_release_asset_to_s3(version)
      ilog.start_threaded "Transferring #{version} to S3" do |s|
        key = filename_for_version(version)
        s.success "Uploaded s3://#{bucket_name}/#{key} successfully."
      end
    end

    def github_to_s3(version, s3_name)
      Dir.mktmpdir('github_to_s3', Dir.getwd) do |tmpdir|
        Dir.chdir(tmpdir) do
          file = download_from_github(version)
          upload_to_s3(file, s3_name)
        end
      end
    end

    # Uploads the file to s3 and verifies the checksum.
    #
    # @param file [String] File to be uploaded to s3.
    # @param key [String] Name of the object to be created on s3.
    # @raise [RuntimeError] If the file fails to upload correctly after 3
    #                       attempts.
    def upload_to_s3(file, key)
      attempts = 0
      begin
        super

        unless (checksum = checksum_file(file)).nil?
          verify_s3_checksum(key, checksum, attempt: attempts)
        end
      rescue RuntimeError => e
        unless (attempts += 1) > 3
          # Wait 10 seconds before trying again.
          sleep 10
          retry
        end

        raise e
      end
    end

    # Downloads the release build from github and verifies the checksum.
    #
    # @param version [String] Version to be downloaded
    # @param [String] Build file downloaded.
    # @raise [RuntimeError] If the file fails to download correctly after 3
    #                       attempts.
    def download_from_github(version)
      file_pattern = "*#{version}*.tar.gz"
      attempts = 0

      Retriable.retriable on: RuntimeError do
        # Make sure the directory is empty before downloading the release.
        FileUtils.rm(Dir.glob('*'))

        # Download the release and find the actual build file.
        sh_out("hub release download #{version}")

        raise "File '#{file_pattern}' not found." if Dir.glob(file_pattern).empty?

        file = Dir.glob(file_pattern).fetch(0)
        unless (checksum = checksum_file(file)).nil?
          verify_download_checksum(file, checksum, attempt: attempts)
        end
        attempts += 1

        file
      end
    end

    # Find the checksum file for a release, if there is one.
    #
    # @param build_file [String] Build file to get the checksum for.
    # @return [String] Checksum file or nil.
    def checksum_file(build_file)
      basename = File.basename(build_file, '.tar.gz')
      Dir.glob("#{basename}.md5").fetch(0, nil)
    end

    # Verifies the checksum for a file downloaded from github.
    #
    # @param build_file [String] Build file to verify.
    # @param checksum_file [String] Checksum file to verify the build.
    # @param attempt [Integer] The attempt for this verification.
    def verify_download_checksum(build_file, checksum_file, attempt: 0)
      expected = File.read(checksum_file)
      actual = Digest::MD5.file(build_file).hexdigest
      if actual != expected
        log.error("GitHub fie #{build_file} checksum should be #{expected} " \
                  "but was #{actual}.")
        backup_failed_github_file(build_file, attempt)
        raise "Checksum for #{build_file} could not be verified."
      end

      log.info('Verified downloaded file checksum.')
    end

    # Backs up the failed file from a github verification.
    #
    # @param build_file [String] The build file to backup.
    # @param attempt [Integer] Which attempt to verify the file failed.
    def backup_failed_github_file(build_file, attempt)
      basename = File.basename(build_file, '.tar.gz')
      destination = File.join(Dir.tmpdir, basename,
                              ".gh.failure.#{attempt}.tar.gz")
      FileUtils.cp(build_file, destination)
      log.info("Copied #{build_file} to #{destination}")
    end

    # Verifies the checksum for a file uploaded to s3.
    #
    # Uses a HEAD request and uses the etag, which is an MD5 hash.
    #
    # @param s3_name [String] The object's name on s3.
    # @param checksum_file [String] Checksum file to verify the build.
    # @param attempt [Integer] The attempt for this verification.
    def verify_s3_checksum(s3_name, checksum_file, attempt: 0)
      headers = s3_client.head_object(
        key: s3_name,
        bucket: @bucket_name
      )
      expected = File.read(checksum_file)
      actual = headers.etag.tr('"', '')
      if actual != expected
        log.error("S3 file #{s3_name} checksum should be #{expected} but " \
                  "was #{actual}.")
        backup_failed_s3_file(s3_name, attempt)
        raise "Checksum for #{s3_name} could not be verified."
      end

      log.info('Verified uploaded file checksum.')
    end

    # Backs up the failed file from an s3 verification.
    #
    # @param s3_name [String] The object's name on s3.
    # @param attempt [Integer] Which attempt to verify the file failed.
    def backup_failed_s3_file(s3_name, attempt)
      basename = File.basename(s3_name, '.tar.gz')
      destination = "#{Dir.tmpdir}/#{basename}.s3.failure.#{attempt}.tar.gz"
      s3_client.get_object(
        response_target: destination,
        key: s3_name,
        bucket: @bucket_name
      )
      log.info("Copied #{s3_name} to #{destination}")
    end

    def doctor_check_hub_release_download
      sh_out('hub release download --help')
    rescue StandardError
      critical '`hub release download` command missing, upgrade hub. ' \
               'See https://github.com/github/hub/pull/1103'
    else
      success '`hub release download` command available.'
    end
  end
end
