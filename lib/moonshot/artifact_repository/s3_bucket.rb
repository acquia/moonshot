require 'moonshot/unicode_table'
require 'moonshot/s3_builds_printer'

# The S3Bucket stores builds in an S3 Bucket.
#
# For example:
#
# def MyApplication < Moonshot::CLI
#   self.artifact_repository = S3Bucket.new('my-application-builds')
# end
class Moonshot::ArtifactRepository::S3Bucket
  include Moonshot::ResourcesHelper
  include Moonshot::CredsHelper
  include Moonshot::DoctorHelper

  attr_reader :bucket_name

  def initialize(bucket_name, prefix: '')
    @bucket_name = bucket_name
    @prefix = prefix
  end

  def store_hook(build_mechanism, version_name)
    unless build_mechanism.respond_to?(:output_file)
      raise "S3Bucket does not know how to store artifacts from #{build_mechanism.class}, no method '#output_file'." # rubocop:disable LineLength
    end

    file = build_mechanism.output_file
    bucket_name = @bucket_name
    key = filename_for_version(version_name)

    ilog.start_threaded "Uploading #{file} to s3://#{bucket_name}/#{key}" do |s|
      upload_to_s3(file, key)
      s.success "Uploaded s3://#{bucket_name}/#{key} successfully."
    end
  end

  def filename_for_version(version_name)
    "#{@prefix}#{version_name}.tar.gz"
  end

  def list_builds_hook(limit, filter)
    builds = list_builds
    t = Moonshot::UnicodeTable.new('')
    Moonshot::S3BuildsPrinter.new(builds, limit, filter, t).print
    t.draw_children
  end

  private

  def upload_to_s3(file, key)
    s3_client.put_object(
      acl: 'bucket-owner-full-control',
      key: key,
      body: File.open(file),
      bucket: @bucket_name,
      storage_class: 'STANDARD_IA'
    )
  end

  def list_builds
    resp = s3_client.list_objects(
      bucket: @bucket_name
    )
    resp.contents
  end

  def doctor_check_bucket_exists
    s3_client.get_bucket_location(bucket: @bucket_name)
    success "Bucket '#{@bucket_name}' exists."
  rescue => e
    # This is warning because the role you use for deployment may not actually
    # be able to read builds, however the instance role assigned to the nodes
    # might.
    str = "Could not get information about bucket '#{@bucket_name}'."
    warning(str, e.message)
  end

  def doctor_check_bucket_writable
    s3_client.put_object(
      key: 'test-object',
      body: '',
      bucket: @bucket_name,
      storage_class: 'REDUCED_REDUNDANCY'
    )
    s3_client.delete_object(key: 'test-object', bucket: @bucket_name)
    success 'Bucket is writable, new builds can be uploaded.'
  rescue => e
    # This is a warning because you may deploy to an environment where you have
    # read access to builds, but could not publish a new build.
    warning('Could not write to bucket, you may still be able to deploy existing builds.', e.message) # rubocop:disable LineLength
  end
end
