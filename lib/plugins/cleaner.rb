require 'rubygems/package'
require_relative '../moonshot/creds_helper'

module Moonshot
  module Plugins
    # Moonshot plugin class for removing artifacts when a stage gets deleted.
    class Cleaner # rubocop:disable Metrics/ClassLength
      include Moonshot::CredsHelper

      def initialize(bucket_name)
        @bucket_name = bucket_name
      end

      def pre_delete(resources)
        app_name = resources.stack.app_name
        stack_name = resources.stack.name
        resources.ilog.start "Starting to delete artifacts for app: #{app_name} and stack: #{stack_name}" do |s|
          arts = retrieve_artifact_names(stack_name)
          delete_artifacts arts
          s.success "Deleted app: '#{app_name}' and stack: '#{stack_name}' bucket: '#{@bucket_name}'"
        end
      end

      private

      def retrieve_artifact_names(name)
        objs = s3_client.list_objects(bucket: @bucket_name, prefix: "#{name}")
        valid_keys = []
        objs.contents.each { |o| valid_keys << o.key if o.key =~ /^#{name}[\.-]/ }
        raise Thor::Error,
              "Artifact not found with name:" \
              "#{name} in bucket: #{@bucket_name}!" if valid_keys.count < 1
        valid_keys
      end

      def delete_artifacts(artifacts)
        objects = artifacts.map { |a| { key: a } }
        resp = s3_client.delete_objects(bucket: @bucket_name,
                                        delete: { objects: objects,
                                                  quiet: false } )
        raise Thor::Error,
              "Artifacts could not be deleted." \
              "The following error occured: #{resp.errors}" if resp.errors.count > 0
      end
    end
  end
end
