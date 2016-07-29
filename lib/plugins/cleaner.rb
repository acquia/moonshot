require 'rubygems/package'
require_relative '../moonshot/creds_helper'
require_relative '../moonshot/resources_helper'

module Moonshot
  module Plugins
    # Moonshot plugin class for removing artifacts when a stage gets deleted.
    class Cleaner
      include Moonshot::CredsHelper
      include Moonshot::ResourcesHelper

      AWS_OBJECT_LIMIT = 1000

      def initialize(bucket_name)
        raise ArgumentError if bucket_name.empty?
        @bucket_name = bucket_name
      end

      def post_delete(resources)
        @resources = resources
        ilog.start "Starting to delete artifacts for stack: #{stack.name}" do |s|
          arts = retrieve_artifact_names(stack.name)
          if arts.empty?
            s.success 'No artifacts found, nothing to delete.'
          else
            delete_artifacts(arts)
            s.success "Deleted artifacts for stack: '#{stack.name}' in bucket: '#{@bucket_name}'"
          end
        end
      end

      def retrieve_artifact_names(name)
        objs = s3_client.list_objects(bucket: @bucket_name, prefix: name)
        objs.contents.map(&:key).select { |k| k =~ /^#{name}(\-\d+)?\.(tar\.gz|zip|tar)$/ }
      end

      def delete_artifacts(artifacts)
        objects = artifacts.map { |a| { key: a } }
        objects.each_slice(AWS_OBJECT_LIMIT) do |s|
          resp = s3_client.delete_objects(bucket: @bucket_name,
                                          delete: { objects: s })
          ilog.error "Could not delete artifacts. Error: #{resp.errors}" unless resp.errors.empty?
        end
      end
    end
  end
end
