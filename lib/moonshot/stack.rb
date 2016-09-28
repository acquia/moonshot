require_relative 'creds_helper'
require_relative 'doctor_helper'

require_relative 'yaml_stack_template'
require_relative 'json_stack_template'
require_relative 'stack_parameter_printer'
require_relative 'stack_output_printer'
require_relative 'stack_asg_printer'
require_relative 'unicode_table'
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

    # TODO: Refactor more of these parameters into the config object.
    def initialize(name, app_name:, log:, ilog:, config: StackConfig.new)
      @name = name
      @app_name = app_name
      @log = log
      @ilog = ilog
      @config = config
      yield @config if block_given?
    end

    def create
      import_parent_parameters

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

    def update
      raise Thor::Error, "No stack found #{@name.blue}!" unless stack_exists?

      should_wait = true
      @ilog.start "Updating #{stack_name}." do |s|
        if update_stack
          s.success "Initiated update for #{stack_name}."
        else
          s.success 'No Stack update required.'
          should_wait = false
        end
      end

      success = should_wait ? wait_for_stack_state(:stack_update_complete, 'updated') : true
      raise Thor::Error, 'Failed to update the CloudFormation Stack.' unless success
      success
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

    # Build a hash of overrides that would be applied to this stack by an
    # update.
    def overrides
      if File.exist?(parameters_file)
        YAML.load_file(parameters_file) || {}
      else
        {}
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
      @template ||= load_template_file
    end

    # @return [String] the path to the template file.
    def template_file
      json = json_template_path
      yaml = yaml_template_path

      @template_file ||= Dir[json].first || Dir[yaml].first

      raise 'CloudFormation template not found at'\
            "#{json} or #{yaml}!" unless @template_file

      @template_file
    end

    # @return [String] the path to the parameters file.
    def parameters_file
      File.join(Dir.pwd, 'cloud_formation', 'parameters', "#{@name}.yml")
    end

    def add_parameter_overrides(hash)
      new_overrides = hash.merge(overrides)
      File.open(parameters_file, 'w') do |f|
        YAML.dump(new_overrides, f)
      end
    end

    private

    def stack_name
      "CloudFormation Stack #{@name.blue}"
    end

    def load_parameters_file
      @ilog.msg "Loading stack parameters file '#{parameters_file}'."
      result = stack_parameter_overrides

      if result.empty?
        @ilog.msg "No parameters file for #{@name.blue}, using defaults."
        return result
      end

      @ilog.msg 'Setting stack parameter overrides:'
      result.each do |e|
        @ilog.msg "   #{e[:parameter_key]}: #{e[:parameter_value]}"
      end
    end

    def json_template_path
      "#{raw_template_file_name}.json"
    end

    def yaml_template_path
      "#{raw_template_file_name}.yml"
    end

    # @return [String] the path to the template file without extension.
    def raw_template_file_name
      @raw_template_file_name ||= File.join(Dir.pwd, 'cloud_formation', @app_name)
    end

    def load_template_file
      json_template = JsonStackTemplate.new(json_template_path, log: @log)
      yaml_template = YamlStackTemplate.new(yaml_template_path, log: @log)
      case
      when json_template.exist?
        json_template
      when yaml_template.exist?
        yaml_template
      else
        raise "CloudFormation template not found at #{json_template_path} "\
              "or #{yaml_template_path}!" unless @template_file
      end
    end

    def stack_parameter_overrides
      overrides.map do |k, v|
        { parameter_key: k, parameter_value: v.to_s }
      end
    end

    def stack_parameters
      template.parameters.map(&:name)
    end

    def import_parent_parameters
      add_parameter_overrides(parent_stack_outputs)
    end

    # Return a Hash of parent stack outputs that match parameter names for this
    # stack.
    def parent_stack_outputs
      result = {}

      @config.parent_stacks.each do |stack_name|
        resp = cf_client.describe_stacks(stack_name: stack_name)
        raise "Parent Stack #{stack_name} not found!" unless resp.stacks.size == 1

        # If there is an input parameters matching a stack output, pass it.
        resp.stacks[0].outputs.each do |output|
          if stack_parameters.include?(output.output_key)
            result[output.output_key] = output.output_value
          end
        end
      end

      result
    end

    # @return [Aws::CloudFormation::Types::Stack]
    def get_stack(name)
      stacks = cf_client.describe_stacks(stack_name: name).stacks
      raise Thor::Error, "Could not describe stack: #{name}" if stacks.empty?

      stacks.first
    rescue Aws::CloudFormation::Errors::ValidationError
      raise Thor::Error, "Could not describe stack: #{name}"
    end

    def create_stack
      cf_client.create_stack(
        stack_name: @name,
        template_body: template.body,
        capabilities: ['CAPABILITY_IAM'],
        parameters: load_parameters_file,
        tags: [
          { key: 'ah_stage', value: @name }
        ]
      )
    rescue Aws::CloudFormation::Errors::AccessDenied
      raise Thor::Error, 'You are not authorized to perform create_stack calls.'
    end

    # @return [Boolean]
    #   true if a stack update was required and initiated, false otherwise.
    def update_stack
      cf_client.update_stack(
        stack_name: @name,
        template_body: template.body,
        capabilities: ['CAPABILITY_IAM'],
        parameters: @config.parameter_strategy.parameters(
          overrides,
          parameters,
          template
        )
      )
      true
    rescue Aws::CloudFormation::Errors::ValidationError => e
      raise Thor::Error, e.message unless
        e.message == 'No updates are to be performed.'
      false
    end

    # TODO: Refactor this into it's own class.
    def wait_for_stack_state(wait_target, past_tense_verb) # rubocop:disable AbcSize
      result = true

      stack_id = get_stack(@name).stack_id

      events = StackEventsPoller.new(cf_client, stack_id)
      events.show_only_errors unless @config.show_all_events

      @ilog.start_threaded "Waiting for #{stack_name} to be successfully #{past_tense_verb}." do |s|
        begin
          cf_client.wait_until(wait_target, stack_name: stack_id) do |w|
            w.delay = 10
            w.max_attempts = 180 # 30 minutes.
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
      cf_client.validate_template(template_body: template.body)
      success('CloudFormation template is valid.')
    rescue => e
      critical('Invalid CloudFormation template!', e.message)
    end
  end
end
