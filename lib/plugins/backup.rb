# frozen_string_literal: true

require 'rubygems/package'
require 'zlib'
require 'yaml'

module Moonshot
  module Plugins
    # Moonshot plugin class for deflating and uploading files on given hooks
    class Backup # rubocop:disable Metrics/ClassLength
      include Moonshot::CredsHelper

      attr_accessor :bucket,
                    :buckets,
                    :files,
                    :hooks,
                    :target_name,
                    :backup_parameters,
                    :backup_template,
                    :bucket_region

      def initialize
        yield self if block_given?
        validate_configuration
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
          b.backup_parameters = true
          b.backup_template = true
          b.hooks = %i[post_create post_update]
        end
      end

      # Main worker method, creates a tarball of the given files, and uploads
      # to an S3 bucket.
      #
      # @param resources [Resources] injected Moonshot resources
      def backup(resources)
        raise ArgumentError if resources.nil?

        @app_name = resources.controller.config.app_name
        @stack_name = resources.stack.name
        @target_name = render(@target_name)
        @target_bucket = define_bucket
        @parameters = resources.stack.parameters

        return if @target_bucket.nil?

        resources.ilog.start("#{log_message} in progress.") do |s|
          tar_out = tar(@files)
          zip_out = zip(tar_out)
          upload(zip_out)

          s.success("#{log_message} succeeded.")
        rescue StandardError => e
          s.failure("#{log_message} failed: #{e}")
        ensure
          tar_out&.close
          zip_out&.close
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
          # adding user files
          unless target_files.nil? || target_files.empty?
            target_files.each do |file|
              file = render(file)
              add_file_to_tar(writer, file)
            end
          end

          # adding parameters
          if @backup_parameters && Moonshot.config.answer_file
            add_str_to_tar(
              writer,
              Moonshot.config.answer_file,
              @parameters
            )
          end

          # adding template file
          if @backup_template
            template_file_path = render('cloud_formation/%{app_name}.json')
            add_file_to_tar(writer, template_file_path)
          end
        end
        tar_stream.seek(0)
        tar_stream
      end

      # Helper method to add a file to an inmemory tar archive.
      #
      # @param writer [TarWriter]
      # @param file_name [String]
      def add_file_to_tar(writer, file_name)
        writer.add_file(File.basename(file_name), 0644) do |io|
          File.open(file_name, 'r') { |f| io.write(f.read) }
        rescue Errno::ENOENT
          warn "'#{file_name}' was not found."
        end
      end

      # Helper method to add a file based on an input String as content
      # to an inmemory tar archive.
      #
      # @param writer [TarWriter]
      # @param target_filename [String]
      # @param content [String]
      def add_str_to_tar(writer, target_filename, content)
        writer.add_file(File.basename(target_filename), 0644) do |io|
          io.write(content.to_yaml)
        end
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
        opts = {}
        opts[:region] = @bucket_region if @bucket_region
        s3_client(**opts).put_object(
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
        # returning already calculated bucket name
        if @target_bucket
          @target_bucket
        # single bucket for all accounts
        elsif @bucket
          @bucket
        # calculating bucket based on account name
        elsif @buckets
          bucket_by_account(iam_account)
        end
      end

      def bucket_by_account(account)
        @buckets[account]
      end

      def validate_configuration
        validate_buckets
        validate_redundant_configuration
        validate_targets
        validate_hooks
      end

      def validate_buckets
        raise ArgumentError, 'You must specify a target bucket.' \
          if (@bucket.nil? || @bucket.empty?) \
          && (@buckets.nil? || @buckets.empty?)
      end

      def validate_redundant_configuration
        raise ArgumentError, 'You can not specify both `bucket` and `buckets`.' \
          if @bucket && @buckets
      end

      def validate_targets
        raise ArgumentError, 'You must specify files to back up.' \
          if (@files.nil? || @files.empty?) \
          && (!@backup_parameters && !@backup_template)
      end

      def validate_hooks
        raise ArgumentError, 'You must specify a hook / hooks to run the backup on.' \
          if hooks.nil? || hooks.empty?

        raise ArgumentError, '`pre_create` and `post_delete` hooks are not supported.' \
          if hooks.include?(:pre_create) || hooks.include?(:post_delete)
      end
    end
  end
end
