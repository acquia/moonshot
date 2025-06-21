# frozen_string_literal: true

require 'erb'

module Moonshot
  class TemplateExists < StandardError; end
  class InvalidTemplate < StandardError; end

  class DynamicTemplate
    # A class to encapsulate template parameters, passing a hash to `process` is
    # only available from Ruby 2.5.
    class Parameters
      def initialize(parameters)
        parameters.each do |k, v|
          instance_variable_set("@#{k}".to_sym, v)
          # Adding an attribute reader for flexibility, this way you can add
          # either `@parameter` or just `parameter` to your template.
          self.class.send(:attr_reader, k.to_sym)
        end
      end

      def expose_binding
        binding
      end
    end

    attr_writer :destination

    def initialize(source:, parameters:, destination:)
      @source = File.read(source)
      @parameters = parameters
      @destination = destination
    end

    def parameters_obj
      @parameters_obj ||= Parameters.new(parameters_file)
    end

    def parameters_file
      env_name = Moonshot.config.environment_name
      @parameters.respond_to?(:call) ? @parameters.call(env_name) : @parameters
    end

    def process
      validate_destination_exists
      new_template = generate_template

      validate_template(new_template)
      write_output(new_template)
    end

    private

    def validate_destination_exists
      return unless File.file?(@destination)

      raise TemplateExists, "Output file '#{@destination}' already exists."
    end

    def validate_template(template)
      if template.bytesize > 50_000 # Leave some margin from the 51,200 limit
        s3_client = Aws::S3::Client.new
        bucket_name = "#{Moonshot.config.template_s3_bucket}"
        template_key = "cdb-network.json"

        # Ensure bucket exists
        begin
          s3_client.head_bucket(bucket: bucket_name)
        rescue Aws::S3::Errors::NotFound
          s3_client.create_bucket(bucket: bucket_name)
        end

        # Upload template to S3
        s3_client.put_object(
          bucket: bucket_name,
          key: template_key,
          body: template
        )

        template_url = "http://#{bucket_name}.s3.amazonaws.com/#{template_key}"

        # Validate using template URL
        Aws::CloudFormation::Client.new.validate_template(
          template_url: template_url
        )
      else
        # Use existing method for small templates
        Aws::CloudFormation::Client.new.validate_template(
          template_body: template
        )
      end
    rescue Aws::CloudFormation::Errors::ValidationError => e
      raise InvalidTemplate, "Invalid template:\n#{e}"
    end

    def generate_template
      ERB.new(minify_template_source).result(parameters_obj.expose_binding)
    end

    def write_output(content)
      File.write(@destination, content)
    end

    def minify_template_source
      JSON.parse(@source).to_json
    end
  end
end
