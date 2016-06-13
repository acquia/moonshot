require 'rubygems/package'
require 'zlib'
require_relative '../moonshot/creds_helper'

module Moonshot::Plugins # rubocop:disable Documentation
  # Defining new method for the ease of use in this
  # particular use-case, and patching to TarWriter
  refine Gem::Package::TarWriter do
    def add(path:, name:, permission: nil)
      rel_path = File.join(path << name)
      permission ||= 0644

      add_file(name, permission) do |io|
        File.open(rel_path, 'r') { |f| io.write(f.read) }
      end
    end
  end
end

using Moonshot::Plugins

module Moonshot
  module Plugins
    # Moonshot plugin class for deflating and
    # uploading files on given hooks
    class Backup
      include Moonshot::CredsHelper

      attr_accessor :bucket,
                    :files,
                    :hooks,
                    :target_name

      def initialize
        yield self if block_given?
        raise ArgumentError if @bucket.nil? || @files.nil? || @files.empty? || @hooks.nil?
        @target_name ||= '%{app_name}_%{timestamp}_%{user}.tar.gz'
      end

      # Factory method to create preconfigured
      # Backup plugins. Uploads current template
      # and parameter files.
      # @param backup [String] target bucket name
      # @return [Backup] configured backup object
      def self.to_bucket(bucket:)
        raise ArgumentError if bucket.nil?
        Moonshot::Plugins::Backup.new do |b|
          b.bucket = bucket
          b.files = [
            { path: %w(cloud_formation), name: '%{app_name}.json' },
            { path: %w(cloud_formation parameters), name: '%{stack_name}.yml' }
          ]
          b.hooks = [:post_create, :post_update]
        end
      end

      # Main worker method, creates a tarball of the given
      # files, and uploads to an S3 bucket.
      # @param resources [Resources] injected Moonshot resources
      def backup(resources) # rubocop:disable Metrics/AbcSize
        raise ArgumentError if resources.nil?

        @app_name = resources.stack.app_name
        @stack_name = resources.stack.name
        @target_name = render(@target_name)

        resources.ilog.start log_message.clone << ' in progress.' do |s|
          begin
            tar_out = tar @files
            zip_out = zip tar_out
            upload zip_out

            s.success log_message.clone << ' succeeded.'
          rescue StandardError => e
            s.failure log_message.clone << " failed: #{e}"
          ensure
            tar_out.close unless tar_out.nil?
            zip_out.close unless zip_out.nil?
          end
        end
      end

      # Dynamically responding to hooks
      # supplied in the constructor
      def method_missing(method_name, *args, &block)
        @hooks.include?(method_name) ? backup(*args) : super
      end

      def respond_to?(method_name, include_private = false)
        @hooks.include?(method_name) || super
      end

      private

      attr_accessor :app_name,
                    :stack_name

      # Creates an IO stream from the passed files
      # @param target_files [String] array of filenames
      # @return tar_stream [IO] IO stream of archived files
      def tar(target_files)
        tar_stream = StringIO.new
        Gem::Package::TarWriter.new(tar_stream) do |writer|
          target_files.each do |file|
            file = render_path file
            writer.add(file)
          end
        end
        tar_stream.seek(0)
        tar_stream
      end

      # Zips up the passed tar stream
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

      # Uploads an object from the pass
      # IO stream to the specified bucket
      # @param io_zip [IO] tar stream
      def upload(io_zip)
        s3_client.put_object(
          acl: 'private',
          bucket: @bucket,
          key: @target_name,
          body: io_zip
        )
      end

      # Renders string with the specified placeholders
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

      # Renders string with the specified placeholders
      # @param file [String] array of raw strings
      # @return [String] array of rendered strings
      def render_path(file)
        file[:path] =
          file[:path].map do |f|
            render f
          end
        file[:name] = render file[:name]
        file
      end

      def log_message
        "Uploading '#{@target_name}' to '#{@bucket}'"
      end
    end
  end
end
