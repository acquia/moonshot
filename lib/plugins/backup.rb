require 'rubygems/package'
require 'zlib'
require_relative '../moonshot/creds_helper'

module Moonshot::Plugins # rubocop:disable Documentation
  # Monkeypatching TarWriter for our
  # needs to improve clarity
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
        raise ArgumentError if @bucket.nil? || @files.nil? || @hooks.nil?
      end

      def backup(resources)
        @app_name = resources.stack.app_name
        @stack_name = resources.stack.name
        @target_name ||= '%{app_name}_%{timestamp}_%{user}.tar.gz'

        tar_out = tar @files
        zip_out = zip tar_out
        upload zip_out
      rescue StandardError => e
        raise e
      ensure
        tar_out.close unless tar_out.nil?
        zip_out.close unless zip_out.nil?
      end

      # dynamically responding to hooks
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

      # returns a tar IO object
      # from the passed files
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

      # returns a tarball IO object
      # from the passed tar file
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
        s3_client.put_object(
          acl: 'private',
          bucket: @bucket,
          key: render(@target_name),
          body: io_zip
        )
      end

      def render(placeholder)
        format(
          placeholder,
          app_name: @app_name,
          stack_name: @stack_name,
          timestamp: Time.now.to_i.to_s,
          user: ENV['USER']
        )
      end

      def render_path(file)
        file[:path] =
          file[:path].map do |f|
            render f
          end
        file[:name] = render file[:name]
        file
      end
    end
  end
end
