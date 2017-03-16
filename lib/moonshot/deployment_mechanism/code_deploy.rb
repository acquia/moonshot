require 'colorize'

# This mechanism is used to deploy software to an auto-scaling group within
# a stack. It currently only works with the S3Bucket ArtifactRepository.
#
# Usage:
# class MyApp < Moonshot::CLI
#   self.artifact_repository = S3Bucket.new('foobucket')
#   self.deployment_mechanism = CodeDeploy.new(asg: 'AutoScalingGroup')
# end
class Moonshot::DeploymentMechanism::CodeDeploy # rubocop:disable ClassLength
  include Moonshot::ResourcesHelper
  include Moonshot::CredsHelper
  include Moonshot::DoctorHelper

  DEFAULT_ROLE_NAME = 'CodeDeployRole'.freeze

  # @param asg [Array, String]
  #   The logical name of the AutoScalingGroup to create and manage a Deployment
  #   Group for in CodeDeploy.
  # @param optional_asg [Array, String]
  #   The logical name of the AutoScalingGroup to create and manage a Deployment
  #   Group for in CodeDeploy. This ASG doesn't have to exist. If it does, it
  #   will be added to the Deployment Group.
  # @param role [String]
  #   IAM role with AWSCodeDeployRole policy. CodeDeployRole is considered as
  #   default role if its not specified.
  # @param app_name [String, nil] (nil)
  #   The name of the CodeDeploy Application. By default, this is the same as
  #   the stack name, and probably what you want. If you have multiple
  #   deployments in a single Stack, they must have unique names.
  # @param group_name [String, nil] (nil)
  #   The name of the CodeDeploy Deployment Group. By default, this is the same
  #   as app_name.
  # @param config_name [String]
  #   Name of the Deployment Config to use for CodeDeploy,  By default we use
  #   CodeDeployDefault.OneAtATime.
  # rubocop:disable Metrics/ParameterLists
  def initialize(
      asg: [],
      optional_asg: [],
      role: DEFAULT_ROLE_NAME,
      app_name: nil,
      group_name: nil,
      config_name: 'CodeDeployDefault.OneAtATime')
    @asg_logical_ids = Array(asg)
    @optional_asg_logical_ids = Array(optional_asg)
    @app_name = app_name
    @group_name = group_name
    @codedeploy_role = role
    @codedeploy_config = config_name
    @ignore_app_stop_failures = false
  end

  def post_create_hook
    create_application_if_needed
    create_deployment_group_if_needed

    wait_for_asg_capacity
  end

  def post_update_hook
    post_create_hook

    unless deployment_group_ok? # rubocop:disable GuardClause
      delete_deployment_group
      create_deployment_group_if_needed
    end
  end

  def status_hook
    t = Moonshot::UnicodeTable.new('')
    application = t.add_leaf("CodeDeploy Application: #{app_name}")
    application.add_line(code_deploy_status_msg)
    t.draw_children
  end

  def deploy_hook(artifact_repo, version_name)
    success = true
    deployment_id = nil

    ilog.start_threaded 'Creating Deployment' do |s|
      res = create_deployment(artifact_repo, version_name)
      deployment_id = res.deployment_id
      s.continue "Created Deployment #{deployment_id.blue}."
      success = wait_for_deployment(deployment_id, s)
    end

    handle_deployment_failure(deployment_id) unless success
  end

  def post_delete_hook
    ilog.start 'Cleaning up CodeDeploy Application' do |s|
      if application_exists?
        cd_client.delete_application(application_name: app_name)
        s.success "Deleted CodeDeploy Application '#{app_name}'."
      else
        s.success "CodeDeploy Application '#{app_name}' does not exist."
      end
    end
  end

  def deploy_cli_hook(parser)
    parser.on('--ignore-app-stop-failures', TrueClass, 'Continue deployment on ApplicationStop failures') do |v| # rubocop:disable LineLength
      puts "ignore = #{v}"
      @ignore_app_stop_failures = v
    end

    parser
  end

  alias push_cli_hook deploy_cli_hook

  private

  # By default, use the stack name as the application name, unless one has been
  # provided.
  def app_name
    @app_name || stack.name
  end

  # By default, use the stack name as the deployment group name, unless one has
  # been provided.
  def group_name
    @group_name || stack.name
  end

  def pretty_app_name
    "CodeDeploy Application #{app_name.blue}"
  end

  def pretty_deploy_group
    "CodeDeploy Deployment Group #{app_name.blue}"
  end

  def create_application_if_needed
    ilog.start "Creating #{pretty_app_name}." do |s|
      if application_exists?
        s.success "#{pretty_app_name} already exists."
      else
        cd_client.create_application(application_name: app_name)
        s.success "Created #{pretty_app_name}."
      end
    end
  end

  def create_deployment_group_if_needed
    ilog.start "Creating #{pretty_deploy_group}." do |s|
      if deployment_group_exists?
        s.success "CodeDeploy #{pretty_deploy_group} already exists."
      else
        create_deployment_group
        s.success "Created #{pretty_deploy_group}."
      end
    end
  end

  def code_deploy_status_msg
    case [application_exists?, deployment_group_exists?, deployment_group_ok?]
    when [true, true, true]
      'Application and Deployment Group are configured correctly.'.green
    when [true, true, false]
      'Deployment Group exists, but not associated with the correct '\
      "Auto-Scaling Group, try running #{'update'.yellow}."
    when [true, false, false]
      "Deployment Group does not exist, try running #{'create'.yellow}."
    when [false, false, false]
      'Application and Deployment Group do not exist, try running'\
      " #{'create'.yellow}."
    end
  end

  def auto_scaling_groups
    @auto_scaling_groups ||= load_auto_scaling_groups
  end

  def load_auto_scaling_groups
    autoscaling_groups = []
    @asg_logical_ids.each do |asg_logical_id|
      asg_name = stack.physical_id_for(asg_logical_id)
      unless asg_name
        raise "Could not find #{asg_logical_id} resource in Stack."
      end

      groups = as_client.describe_auto_scaling_groups(
        auto_scaling_group_names: [asg_name])
      if groups.auto_scaling_groups.empty?
        raise "Could not find ASG #{asg_name}."
      end

      autoscaling_groups.push(groups.auto_scaling_groups.first)
    end
    @optional_asg_logical_ids.each do |asg_logical_id|
      asg_name = stack.physical_id_for(asg_logical_id)
      next unless asg_name
      groups = as_client.describe_auto_scaling_groups(
        auto_scaling_group_names: [asg_name]
      )
      unless groups.auto_scaling_groups.empty?
        autoscaling_groups.push(groups.auto_scaling_groups.first)
      end
    end
    autoscaling_groups
  end

  def asg_names
    names = []
    auto_scaling_groups.each do |auto_scaling_group|
      names.push(auto_scaling_group.auto_scaling_group_name)
    end
    names
  end

  def application_exists?
    cd_client.get_application(application_name: app_name)
    true
  rescue Aws::CodeDeploy::Errors::ApplicationDoesNotExistException
    false
  end

  def deployment_group
    cd_client.get_deployment_group(
      application_name: app_name, deployment_group_name: group_name)
             .deployment_group_info
  end

  def deployment_group_exists?
    cd_client.get_deployment_group(
      application_name: app_name, deployment_group_name: group_name)
    true
  rescue Aws::CodeDeploy::Errors::ApplicationDoesNotExistException,
         Aws::CodeDeploy::Errors::DeploymentGroupDoesNotExistException
    false
  end

  def deployment_group_ok?
    return false unless deployment_group_exists?
    asgs = deployment_group.auto_scaling_groups
    return false unless asgs
    return false unless asgs.count == auto_scaling_groups.count
    asgs.each do |asg|
      if (auto_scaling_groups.find_index { |a| a.auto_scaling_group_name == asg.name }).nil?
        return false
      end
    end
    true
  end

  def role
    iam_client.get_role(role_name: @codedeploy_role).role
  rescue Aws::IAM::Errors::NoSuchEntity
    # Auto create the IAM Role if it does not exist in the current AWS account
    ilog.start "Missing IAM Role: #{@codedeploy_role.blue}. Creating it now ..." do |s|
      code_deploy_policy = {
        'Version' => '2012-10-17',
        'Statement' => [
          {
            'Sid' => '',
            'Effect' => 'Allow',
            'Principal' => {
              'Service' => [
                'codedeploy.amazonaws.com'
              ]
            },
            'Action' => 'sts:AssumeRole'
          }
        ]
      }

      result = iam_client.create_role(
        role_name: @codedeploy_role,
        assume_role_policy_document: code_deploy_policy.to_json
      )
      iam_client.attach_role_policy(
        role_name: @codedeploy_role,
        policy_arn: 'arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole'
      )
      s.success "Created IAM Role successfully: #{@codedeploy_role.blue}"
      result.role
    end
  end

  def delete_deployment_group
    ilog.start "Deleting #{pretty_deploy_group}." do |s|
      cd_client.delete_deployment_group(
        application_name: app_name,
        deployment_group_name: group_name)
      s.success
    end
  end

  def create_deployment_group
    cd_client.create_deployment_group(
      application_name: app_name,
      deployment_group_name: group_name,
      service_role_arn: role.arn,
      auto_scaling_groups: asg_names)
  end

  def wait_for_asg_capacity
    ilog.start_threaded 'Waiting for AutoScaling Group(s) to reach capacity...' do |s|
      loop do
        asgs_at_capacity = 0
        asgs = load_auto_scaling_groups
        asgs.each do |asg|
          count = asg.instances.count { |i| i.lifecycle_state == 'InService' }
          if asg.desired_capacity == count
            asgs_at_capacity += 1
            s.continue "#{asg.auto_scaling_group_name} DesiredCapacity is #{asg.desired_capacity}, currently #{count} instance(s) are InService." # rubocop:disable LineLength
          end
        end
        break if asgs.count == asgs_at_capacity
        sleep 5
      end

      s.success 'AutoScaling Group(s) up to capacity!'
    end
  end

  def wait_for_deployment(id, step)
    success = true

    loop do
      sleep 5
      info = cd_client.get_deployment(deployment_id: id).deployment_info
      status = info.status

      case status
      when 'Created', 'Queued', 'InProgress'
        step.continue "Waiting for Deployment #{id.blue} to complete, current status is '#{status}'." # rubocop:disable LineLength
      when 'Succeeded'
        step.success "Deployment #{id.blue} completed successfully!"
        break
      when 'Failed', 'Stopped'
        step.failure "Deployment #{id.blue} failed with status '#{status}'"
        success = false
        break
      end
    end

    success
  end

  def handle_deployment_failure(deployment_id)
    instances = cd_client.list_deployment_instances(deployment_id: deployment_id)
                         .instances_list.map do |instance_id|
      cd_client.get_deployment_instance(deployment_id: deployment_id,
                                        instance_id: instance_id)
    end

    instances.map(&:instance_summary).each do |inst_summary|
      next unless inst_summary.status == 'Failed'

      inst_summary.lifecycle_events.each do |event|
        next unless event.status == 'Failed'

        if event.diagnostics.nil?
          ilog.error('Lifecycle event chain is not available.')
        else
          ilog.error(event.diagnostics.message)
          event.diagnostics.log_tail.each_line do |line|
            ilog.error(line)
          end
        end
      end
    end

    raise 'Deployment was unsuccessful!'
  end

  def revision_for_artifact_repo(artifact_repo, version_name)
    case artifact_repo
    when Moonshot::ArtifactRepository::S3Bucket
      s3_revision_for(artifact_repo, version_name)
    when NilClass
      raise 'Must specify an ArtifactRepository with CodeDeploy. Take a look at the S3Bucket example.' # rubocop:disable LineLength
    else
      raise "Cannot use #{artifact_repo.class} to deploy with CodeDeploy."
    end
  end

  def s3_revision_for(artifact_repo, version_name)
    {
      revision_type: 'S3',
      s3_location: {
        bucket: artifact_repo.bucket_name,
        key: artifact_repo.filename_for_version(version_name),
        bundle_type: 'tgz'
      }
    }
  end

  def create_deployment(artifact_repo, version_name)
    cd_client.create_deployment(
      application_name: app_name,
      deployment_group_name: group_name,
      revision: revision_for_artifact_repo(artifact_repo, version_name),
      deployment_config_name: @codedeploy_config,
      description: "Deploying version #{version_name}",
      ignore_application_stop_failures: @ignore_app_stop_failures
    )
  end

  def doctor_check_code_deploy_role
    role
    success("#{@codedeploy_role} exists.")
  rescue => e
    help = <<-EOF
Error: #{e.message}

For information on provisioning an account for use with CodeDeploy, see:
http://docs.aws.amazon.com/codedeploy/latest/userguide/how-to-create-service-role.html
    EOF
    critical("Could not find #{@codedeploy_role}, ", help)
  end

  def doctor_check_auto_scaling_resource_defined
    @asg_logical_ids.each do |asg_logical_id|
      if stack.template.resource_names.include?(asg_logical_id)
        success("Resource '#{asg_logical_id}' exists in the CloudFormation template.") # rubocop:disable LineLength
      else
        critical("Resource '#{asg_logical_id}' does not exist in the CloudFormation template!") # rubocop:disable LineLength
      end
    end
  end
end
