require 'moonshot/artifact_repository/s3_bucket'
require 'moonshot/shell'
require 'securerandom'
require 'semantic'
require 'tmpdir'

module Moonshot::ArtifactRepository
  # S3 Bucket repository backed by GitHub releases.
  # If a SemVer package isn't found in S3, it is copied from GitHub releases.
  class S3BucketViaGithubReleases < S3Bucket
    include Moonshot::BuildMechanism
    include Moonshot::Shell
    include Moonshot::DoctorHelper

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
      if !@output_file && release?(version) && !in_s3?(s3_name)
        github_to_s3(version, s3_name)
      end
      s3_name
    end

    private

    def release?(version)
      ::Semantic::Version.new(version)
    rescue ArgumentError
      false
    end

    def in_s3?(key)
      s3_client.head_object(key: key, bucket: bucket_name)
    rescue ::Aws::S3::Errors::NotFound
      false
    end

    def attach_release_asset(version, file)
      # -m '' leaves message unchanged.
      cmd = "hub release edit #{version} -m '' --attach=#{file}"
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
          sh_out("hub release download #{version}")
          file = Dir.glob("*#{version}*.tar.gz").fetch(0)
          upload_to_s3(file, s3_name)
        end
      end
    end

    add_doctor_check :doctor_check_hub_release_download
    def doctor_check_hub_release_download
      sh_out('hub release download --help')
    rescue
      critical '`hub release download` command missing, upgrade hub.' \
               ' See https://github.com/github/hub/pull/1103'
    else
      success '`hub release download` command available.'
    end
  end
end
