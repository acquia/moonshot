module Moonshot
  module Plugins
    # Plugin to ensure CodeDeploy has all necessary S3 buckets created.
    # Defaults to using ENV['AWS_REGION'] as default region if not configured.
    class CodeDeploySetup
      include Moonshot::CredsHelper

      attr_reader :name, :prefix, :regions

      def initialize(name, prefix: '', regions: [ENV['AWS_REGION']])
        @regions = regions.reject(&:nil?)
        if @regions.empty?
          raise ArgumentError, 'CodeDeploySetup requires at least one region.' \
                               ' Set regions argument or ENV[\'AWS_REGION\'].'
        end

        @name = name
        @prefix = prefix
      end

      def bucket_name(region = ENV['AWS_REGION'])
        if ENV.key?('S3_BUCKET')
          ENV['S3_BUCKET']
        else
          "#{@name}-#{region}"
        end
      end

      def bucket_prefix
        @prefix.empty? ? '' : "#{@prefix}/"
      end

      # Create an S3 bucket in each supported region for CodeDeploy
      def setup_code_deploy_s3_buckets
        @regions.uniq.each do |region|
          client = s3_client(region: region)
          name = bucket_name(region)
          bucket = Aws::S3::Bucket.new(
            name,
            client: client
          )
          bucket.create unless bucket.exists?
        end
      end

      # Hook entry points to ensure S3 Buckets are available for CodeDeploy
      def run_hook(_resources)
        setup_code_deploy_s3_buckets
      end

      # Moonshot hooks to trigger this plugin
      alias pre_create run_hook
      alias pre_deploy run_hook
    end
  end
end
