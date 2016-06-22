require 'rubygems/package'
require 'zlib'
require_relative '../moonshot/creds_helper'

module Moonshot
  module Plugins
    # Moonshot plugin class for deflating and uploading files on given hooks
    class Backup # rubocop:disable Metrics/ClassLength
      include Moonshot::CredsHelper

      attr_accessor :bucket,
                    :buckets,
                    :files,
                    :hooks,
                    :target_name

      def initialize
        yield self if block_given?
        raise ArgumentError \
          if @files.nil? || @files.empty? || @hooks.nil? || !(@bucket.nil? ^ @buckets.nil?)

        @target_name ||= '%{app_name}_%{timestamp}_%{user}.tar.gz'
      end

      # Factory method to create preconfigured Backup plugins. Uploads current
      # template and parameter files.
      # @param backup [String] target bucket name
      # @return [Backup] configured backup object
      def self.to_bucket(bucket)
        raise ArgumentError if bucket.nil? || bucket.empty?
        Moonshot::Plugins::Backup.new do |b|
          b.bucket = bucket
          b.files = [
            'cloud_formation/%{app_name}.json',
            'cloud_formation/parameters/%{stack_name}.yml'
          ]
          b.hooks = [:post_create, :post_update]
        end
      end

      # Main worker method, creates a tarball of the given files, and uploads
      # to an S3 bucket.
      #
      # @param resources [Resources] injected Moonshot resources
      def backup(resources) # rubocop:disable Metrics/AbcSize
        raise ArgumentError if resources.nil?

        @app_name = resources.stack.app_name
        @stack_name = resources.stack.name
        @target_name = render(@target_name)
        @target_bucket = define_bucket

        return if @target_bucket.nil?

        resources.ilog.start("#{log_message} in progress.") do |s|
          begin
            tar_out = tar(@files)
            zip_out = zip(tar_out)
            upload(zip_out)

            s.success("#{log_message} succeeded.")
          rescue StandardError => e
            s.failure("#{log_message} failed: #{e}")
          ensure
            tar_out.close unless tar_out.nil?
            zip_out.close unless zip_out.nil?
          end
        end
      end

      # Dynamically responding to hooks supplied in the constructor
      def method_missing(method_name, *args, &block)
        @hooks.include?(method_name) ? backup(*args) : super
      end

      def respond_to?(method_name, include_private = false)
        @hooks.include?(method_name) || super
      end

      private

      attr_accessor :app_name,
                    :stack_name,
                    :target_bucket

      # Create a tar archive in memory, returning the IO object pointing at the
      # beginning of the archive.
      #
      # @param target_files [Array<String>]
      # @return tar_stream [IO]
      def tar(target_files)
        tar_stream = StringIO.new
        Gem::Package::TarWriter.new(tar_stream) do |writer|
          target_files.each do |file|
            file = render(file)

            writer.add_file(File.basename(file), 0644) do |io|
              File.open(file, 'r') { |f| io.write(f.read) }
            end
          end
        end
        tar_stream.seek(0)
        tar_stream
      end

      # Create a zip archive in memory, returning the IO object pointing at the
      # beginning of the zipfile.
      #
      # @param io_tar [IO] tar stream
      # @return zip_stream [IO] IO stream of zipped file
      def zip(io_tar)
        zip_stream = StringIO.new
        Zlib::GzipWriter.wrap(zip_stream) do |gz|
          gz.write(io_tar.read)
          gz.finish
        end
        zip_stream.seek(0)
        zip_stream
      end

      # Uploads an object from the passed IO stream to the specified bucket
      #
      # @param io_zip [IO] tar stream
      def upload(io_zip)
        s3_client.put_object(
          acl: 'private',
          bucket: @target_bucket,
          key: @target_name,
          body: io_zip
        )
      end

      # Renders string with the specified placeholders
      #
      # @param io_zip [String] raw string with placeholders
      # @return [String] rendered string
      def render(placeholder)
        format(
          placeholder,
          app_name: @app_name,
          stack_name: @stack_name,
          timestamp: Time.now.to_i.to_s,
          user: ENV['USER']
        )
      end

      def log_message
        "Uploading '#{@target_name}' to '#{@target_bucket}'"
      end

      def iam_account
        iam_client.list_account_aliases.account_aliases.first
      end

      def define_bucket
        case
        # returning already calculated bucket name
        when !@target_bucket.nil?
          @target_bucket
        # single bucket for all accounts
        when !@bucket.nil?
          @bucket
        # calculating bucket based on account name
        when !@buckets.nil?
          bucket_by_account(iam_account)
        end
      end

      def bucket_by_account(account)
        @buckets[account] if @buckets.include?(account)
      end
    end
  end
end
