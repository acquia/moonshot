require 'yaml'

module Moonshot
  # The Stack wraps all CloudFormation actions performed by Moonshot. It
  # stores the state of the active stack running on AWS, but contains a
  # reference to the StackTemplate that would be applied with an update
  # action.
  class Stack # rubocop:disable ClassLength
    include CredsHelper
    include DoctorHelper

    attr_reader :app_name
    attr_reader :name

    def initialize(config)
      @config = config
      @ilog = config.interactive_logger
      @name = [@config.app_name, @config.environment_name].join('-')

      yield @config if block_given?
    end

    def create
      should_wait = true
      @ilog.start "Creating #{stack_name}." do |s|
        if stack_exists?
          s.success "#{stack_name} already exists."
          should_wait = false
        else
          create_stack
          s.success "Created #{stack_name}."
        end
      end

      should_wait ? wait_for_stack_state(:stack_create_complete, 'created') : true
    end

    def update(dry_run:, force:)
      raise "No stack found #{@name.blue}!" unless stack_exists?

      change_set = ChangeSet.new(new_change_set, @name)
      wait_for_change_set(change_set)
      return unless change_set.valid?

      if dry_run
        change_set.display_changes
      elsif !force
        change_set.display_changes
        change_set.confirm? || raise('ChangeSet rejected!')
      end

      execute_change_set(change_set)
    end

    def delete
      should_wait = true
      @ilog.start "Deleting #{stack_name}." do |s|
        if stack_exists?
          cf_client.delete_stack(stack_name: @name)
          s.success "Initiated deletion of #{stack_name}."
        else
          s.success "#{stack_name} does not exist."
          should_wait = false
        end
      end

      should_wait ? wait_for_stack_state(:stack_delete_complete, 'deleted') : true
    end

    def status
      if exists?
        puts "#{stack_name} exists."
        t = UnicodeTable.new('')
        StackParameterPrinter.new(self, t).print
        StackOutputPrinter.new(self, t).print
        StackASGPrinter.new(self, t).print
        t.draw_children
      else
        puts "#{stack_name} does NOT exist."
      end
    end

    def parameters
      get_stack(@name)
        .parameters
        .map { |p| [p.parameter_key, p.parameter_value] }
        .to_h
    end

    def outputs
      get_stack(@name)
        .outputs
        .map { |o| [o.output_key, o.output_value] }
        .to_h
    end

    def exists?
      cf_client.describe_stacks(stack_name: @name)
      true
    rescue Aws::CloudFormation::Errors::ValidationError
      false
    end
    alias stack_exists? exists?

    def resource_summaries
      cf_client.list_stack_resources(stack_name: @name).stack_resource_summaries
    end

    # @return [String, nil]
    def physical_id_for(logical_id)
      resource_summary = resource_summaries.find do |r|
        r.logical_resource_id == logical_id
      end
      resource_summary.physical_resource_id if resource_summary
    end

    # @return [Array<Aws::CloudFormation::Types::StackResourceSummary>]
    def resources_of_type(type)
      resource_summaries.select do |r|
        r.resource_type == type
      end
    end

    # Return a Hash of the default values defined in the stack template.
    def default_values
      h = {}
      template.parameters.each do |p|
        h[p.name] = h.default
      end
      h
    end

    def template
      load_template_file
    end

    # @return [String] the path to the template file.
    def template_file
      load_template_file.filename
    end

    private

    def stack_name
      "CloudFormation Stack #{@name.blue}"
    end

    def load_template_file
      templates = [
        YamlStackTemplate.new(File.join(@config.project_root, 'moonshot', 'template.yml')),
        JsonStackTemplate.new(File.join(@config.project_root, 'moonshot', 'template.json')),

        # Support the legacy file location from Moonshot 1.0.
        YamlStackTemplate.new(
          File.join(@config.project_root, 'cloud_formation', "#{@config.app_name}.yml")),
        JsonStackTemplate.new(
          File.join(@config.project_root, 'cloud_formation', "#{@config.app_name}.json"))
      ]

      template = templates.find(&:exist?)
      raise 'No template found in moonshot/template.{yml,json}!' unless template
      template
    end

    def stack_parameters
      template.parameters.map(&:name)
    end

    # @return [Aws::CloudFormation::Types::Stack]
    def get_stack(name)
      stacks = cf_client.describe_stacks(stack_name: name).stacks
      raise "Could not describe stack: #{name}" if stacks.empty?

      stacks.first
    rescue Aws::CloudFormation::Errors::ValidationError
      raise "Could not describe stack: #{name}"
    end

    def upload_template_to_s3
      unless @config.template_s3_bucket
        raise 'The S3 bucket to store the template in is not configured.'
      end

      s3_object_key = "#{@name}-#{Time.now.getutc.to_i}-#{File.basename(template.filename)}"
      template_url = "http://#{@config.template_s3_bucket}.s3.amazonaws.com/#{s3_object_key}"

      @ilog.start "Uploading template to #{template_url}" do |s|
        s3_client.put_object(
          bucket: @config.template_s3_bucket,
          key: s3_object_key,
          body: template.body
        )
        s.success "Template has been uploaded successfully to #{template_url}"
      end

      template_url
    end

    def create_stack
      parameters = {
        stack_name: @name,
        capabilities: %w(CAPABILITY_IAM CAPABILITY_NAMED_IAM),
        parameters: @config.parameters.values.map(&:to_cf),
        tags: make_tags
      }
      if @config.template_s3_bucket
        parameters[:template_url] = upload_template_to_s3
      else
        parameters[:template_body] = template.body
      end
      cf_client.create_stack(parameters)
    rescue Aws::CloudFormation::Errors::AccessDenied
      raise 'You are not authorized to perform create_stack calls.'
    end

    def new_change_set
      change_set_name = [
        'moonshot',
        @name,
        Time.now.utc.to_i.to_s
      ].join('-')

      parameters = {
        change_set_name: change_set_name,
        description: "Moonshot update command for application '#{Moonshot.config.app_name}'",
        stack_name: @name,
        capabilities:  %w(CAPABILITY_IAM CAPABILITY_NAMED_IAM),
        parameters: @config.parameters.values.map(&:to_cf)
      }
      if @config.template_s3_bucket
        parameters[:template_url] = upload_template_to_s3
      else
        parameters[:template_body] = template.body
      end

      cf_client.create_change_set(parameters)

      change_set_name
    end

    # TODO: Refactor this into it's own class.
    def wait_for_stack_state(wait_target, past_tense_verb)
      result = true

      stack_id = get_stack(@name).stack_id

      events = StackEventsPoller.new(cf_client, stack_id)
      events.show_only_errors unless @config.show_all_stack_events

      @ilog.start_threaded "Waiting for #{stack_name} to be successfully #{past_tense_verb}." do |s|
        begin
          cf_client.wait_until(wait_target, stack_name: stack_id) do |w|
            w.delay = 10
            w.max_attempts = 360 # 60 minutes.
            w.before_wait do |attempt, resp|
              begin
                events.latest_events.each { |e| @ilog.error(format_event(e)) }
                # rubocop:disable Lint/HandleExceptions
              rescue Aws::CloudFormation::Errors::ValidationError
                # Do nothing.  The above event logging block may result in
                # a ValidationError while waiting for a stack to delete.
              end
              # rubocop:enable Lint/HandleExceptions

              if attempt == w.max_attempts - 1
                s.failure "#{stack_name} was not #{past_tense_verb} after 30 minutes."
                result = false

                # We don't want the interactive logger to catch an exception.
                throw :success
              end
              s.continue "Waiting for CloudFormation Stack to be successfully #{past_tense_verb}, current status '#{resp.stacks.first.stack_status}'." # rubocop:disable LineLength
            end
          end

          s.success "#{stack_name} successfully #{past_tense_verb}." if result
        rescue Aws::Waiters::Errors::FailureStateError
          result = false
          s.failure "#{stack_name} failed to update."
        end
      end

      result
    end

    def make_tags
      default_tags = [
        { key: 'moonshot_application', value: @config.app_name },
        { key: 'moonshot_environment', value: @config.environment_name }
      ]

      if @config.additional_tag
        default_tags << { key: @config.additional_tag, value: @name }
      end

      default_tags
    end

    def format_event(event)
      str = case event.resource_status
            when /FAILED/
              event.resource_status.red
            when /IN_PROGRESS/
              event.resource_status.yellow
            else
              event.resource_status.green
            end
      str << " #{event.logical_resource_id}"
      str << " #{event.resource_status_reason.light_black}" if event.resource_status_reason

      str
    end

    def doctor_check_template_exists
      if File.exist?(template_file)
        success "CloudFormation template found at '#{template_file}'."
      else
        critical "CloudFormation template not found at '#{template_file}'!"
      end
    end

    def doctor_check_template_against_aws
      validate_params = {}
      if @config.template_s3_bucket
        validate_params[:template_url] = upload_template_to_s3
      else
        validate_params[:template_body] = template.body
      end
      cf_client.validate_template(validate_params)
      success('CloudFormation template is valid.')
    rescue => e
      critical('Invalid CloudFormation template!', e.message)
    end

    def wait_for_change_set(change_set)
      @ilog.start_threaded "Waiting for ChangeSet #{change_set.name.blue} to be created." do |s|
        change_set.wait_for_change_set

        if change_set.valid?
          s.success "ChangeSet #{change_set.name.blue} ready!"
        else
          s.failure "ChangeSet failed to create: #{change_set.invalid_reason}"
        end
      end
    end

    def execute_change_set(change_set)
      @ilog.start_threaded "Executing ChangeSet #{change_set.name.blue} for #{stack_name}." do |s|
        change_set.execute
        s.success "Executed ChangeSet #{change_set.name.blue} for #{stack_name}."
      end

      success = wait_for_stack_state(:stack_update_complete, 'updated')
      raise 'Failed to update the CloudFormation Stack.' unless success
      success
    end
  end
end
