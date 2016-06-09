require 'rubygems/package'
require 'zlib'
require_relative '../moonshot/creds_helper'

module Moonshot
  module Plugins
    # Moonshot plugin class for deflating and
    # uploading files on given hooks
    class Backup
      include Moonshot::CredsHelper

      attr_accessor :base_path,
                    :bucket,
                    :files,
                    :hooks,
                    :target_name

      def initialize
        yield self if block_given?

        raise ArgumentError if @base_path.nil? || @bucket.nil? || @files.nil? || @hooks.nil?
      end

      def backup(resources)
        @app_name = resources.stack.app_name
        @stack_name = resources.stack.name
        @target_name ||= '<app_name>_<timestamp>_<user>.tar.gz'

        tar_out = tar @files
        zip_out = zip tar_out
        upload zip_out
      rescue StandardError => e
        raise e
      ensure
        tar_out.close unless tar_out.nil?
        zip_out.close unless zip_out.nil?
      end

      # dynamically responding to the hooks
      # supplied in the constructor
      def method_missing(method_name, *args, &block)
        backup(*args) if @hooks.include?(method_name) || super
      end

      def respond_to?(method_name, include_private = false)
        @hooks.include?(method_name) || super
      end

      private

      attr_accessor :app_name,
                    :stack_name

      def tar(target_files)
        tar_stream = StringIO.new
        Gem::Package::TarWriter.new(tar_stream) do |writer|
          target_files.each do |file|
            writer.add(format(file))
          end
        end
        tar_stream.seek(0)
        tar_stream
      end

      def zip(io_tar)
        zip_stream = StringIO.new
        Zlib::GzipWriter.wrap(zip_stream) do |gz|
          gz.write(io_tar.read)
          gz.finish
        end
        zip_stream.seek(0)
        zip_stream
      end

      def upload(io_zip)
        render_placeholder(@target_name)
        s3_client.put_object(
          acl: 'private',
          bucket: @bucket,
          key: @target_name,
          body: io_zip
        )
      end

      def format(file)
        file = inject_base(file)
        render_placeholder(file[:name])
        file
      end

      def inject_base(file)
        file[:path] = [@base_path.clone] << file[:path]
        file
      end

      def render_placeholder(placeholder)
        placeholder.gsub! '<app_name>', @app_name
        placeholder.gsub! '<stack_name>', @stack_name
        placeholder.gsub! '<timestamp>', Time.now.to_i.to_s
        placeholder.gsub! '<user>', ENV['USER']
      end
    end

    # Monkeypatching TarWriter for our
    # needs to improve clarity
    class Gem::Package::TarWriter
      def add(name:, path:, permission: nil)
        path = File.join(path << name)
        permission ||= 0644

        add_file(name, permission) do |io|
          File.open(path, 'r') { |f| io.write(f.read) }
        end
      end
    end
  end
end
