describe Moonshot::RotateAsgInstances::ASG do
  let(:name) { 'cdb-worker-dev-jarmes-WorkerASG-Q7DYM7901RBY' }
  let(:instance_id) { 'i-585e91dc' }
  let(:instance_id_2) { 'i-685e91dc' }
  let(:ssh_executor) { Moonshot::SSHForkExecutor }
  let(:moonshot_config) { Moonshot.config }
  let(:controller) do
    instance_double('Moonshot::Controller',
                    config: moonshot_config,
                    stack: instance_double(
                      Moonshot::Stack,
                      name: 'test_name',
                      parameters: {}
                    )
    )
  end
  let(:resources) do
    instance_double(
      Moonshot::Resources,
      ilog: instance_double(Moonshot::InteractiveLoggerProxy),
      controller: controller
    )
  end

  let(:asg) do
    instance_double(
      Aws::AutoScaling::AutoScalingGroup,
      name: 'asg'
    )
  end

  let(:ilog) { resources.ilog }
  let(:current_instance) do
    instance_double(
      Aws::AutoScaling::Instance,
      instance_id: instance_id,
      lifecycle_state: 'InService',
      launch_configuration_name: 'configuration-2'
    )
  end

  let(:outdated_instance) do
    instance_double(
      Aws::AutoScaling::Instance,
      instance_id: instance_id_2,
      lifecycle_state: 'InService',
      launch_configuration_name: 'configuration-1'
    )
  end

  before(:each) { stub_cf_client }

  def stub_cf_client
    @cf_client = instance_double(Aws::CloudFormation::Client)
    allow(Aws::CloudFormation::Client).to receive(:new) do
      assert_aws_retry_limit
      @cf_client
    end
    allow(@cf_client).to receive(:validate_template).and_return(true)
  end

  subject { described_class.new(resources) }

  describe '#cycle_instances' do
    before(:each) do
      allow(subject).to receive(:launch_configuration_name) \
        .and_return('configuration-2')
      allow(subject).to receive(:instances).and_return(
        [current_instance, outdated_instance]
      )
    end

    it 'properly cycles ASG instances' do
      expect(ilog).to receive(:start_threaded).with(
        'Rotating ASG instances...'
      )
      ilog.start_threaded('Rotating ASG instances...') do |step|
        @step = step
        expect(subject).to receive(:wait_for_instance).with(
          outdated_instance
        )
        expect(subject).to receive(:detach_instance).with(
          outdated_instance
        ).and_call_original
        expect(subject).to receive(:wait_for_capacity)
        expect(subject).to receive(:shutdown_instance)
          .with(instance_id_2)
        expect(subject).to receive(:name).and_return(name)
        expect(outdated_instance).to receive(:detach)
          .with(should_decrement_desired_capacity: false)

        subject.cycle_instances
      end
    end

    it 'attempts to re-attach if waiting for capacity errors' do
      expect(ilog).to receive(:start_threaded).with(
        'Rotating ASG instances...'
      )
      ilog.start_threaded('Rotating ASG instances...') do |step|
        @step = step
        expect(subject).to receive(:wait_for_instance)
          .with(outdated_instance)
        expect(subject).to receive(:wait_for_capacity).and_raise
        expect(subject).to receive(:reattach_instance)
          .with(outdated_instance)
        expect(subject).to receive(:name).and_return(name)
        expect(outdated_instance).to receive(:detach)
          .with(should_decrement_desired_capacity: false)
        expect { subject.cycle_instances }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#shutdown_instance' do
    let(:public_ip_address) { '10.234.32.21' }
    let(:instance) { instance_double(Aws::EC2::Instance) }
    let(:command_builder) { Moonshot::SSHCommandBuilder }
    subject { super().send(:shutdown_instance, instance_id) }

    before(:each) do
      moonshot_config.ssh_config.ssh_user = 'ci_user'
      moonshot_config.ssh_config.ssh_options = ssh_options
      allow(Aws::EC2::Instance).to receive(:new).and_return(instance)
      allow_any_instance_of(command_builder).to receive(:instance_ip).and_return(public_ip_address)
      allow(instance).to receive(:wait_until_stopped)
    end


    context 'when ssh_options are not defined' do
      let(:ssh_options) { nil }

      it 'issues a shutdown without options to the instance' do
        expect_any_instance_of(ssh_executor).to receive(:run).with(
          "ssh -t -l #{moonshot_config.ssh_config.ssh_user} #{public_ip_address} sudo\\ shutdown\\ -h\\ now"
        )
        subject
      end
    end

    context 'when ssh_options are defined' do
      let(:ssh_options) { '-v -o UserKnownHostsFile=/dev/null' }

      it 'issues a shutdown with options to the instance' do
        expect_any_instance_of(ssh_executor).to receive(:run).with(
          'ssh -t -v -o UserKnownHostsFile=/dev/null ' \
          "-l ci_user #{public_ip_address} sudo\\ shutdown\\ -h\\ now"
        )
        subject
      end
    end
  end

  describe '#detach_instance' do
    it 'detaches instance and waits for capacity' do
      expect(ilog).to receive(:start_threaded).with(
        'Rotating ASG instances...'
      )
      ilog.start_threaded('Rotating ASG instances...') do |step|
        @step = step
        expect(outdated_instance).to receive(:detach).with(
          should_decrement_desired_capacity: false
        )
        expect(subject).to receive(:wait_for_capacity)
        subject.detach_instance(outdated_instance)
      end
    end

    it 're-attaches instance after wait for capacity failed' do
      expect(ilog).to receive(:start_threaded).with(
        'Rotating ASG instances...'
      )
      ilog.start_threaded('Rotating ASG instances...') do |step|
        @step = step
        expect(outdated_instance).to receive(:detach).with(
          should_decrement_desired_capacity: false
        )
        expect(subject).to receive(:wait_for_capacity).and_raise
        expect(subject).to receive(:reattach_instance).with(
          outdated_instance
        )
        expect do
          subject.detach_instance(outdated_instance)
        end.to raise_error(RuntimeError)
      end
    end
  end

  describe '#terminate_instances' do
    let(:stopping_ec2_instance) do
      instance_double(
        Aws::EC2::Instance,
        instance_id: "i-#{SecureRandom.hex(4)}",
        state: Struct.new(:name).new('stopping')
      )
    end

    let(:stopped_ec2_instance) do
      instance_double(
        Aws::EC2::Instance,
        instance_id: "i-#{SecureRandom.hex(4)}",
        state: Struct.new(:name).new('stopped')
      )
    end

    let(:terminated_ec2_instance) do
      instance_double(
        Aws::EC2::Instance,
        instance_id: "i-#{SecureRandom.hex(4)}",
        state: Struct.new(:name).new('terminated')
      )
    end

    let(:ec2_instances) do
      [
        stopping_ec2_instance,
        stopped_ec2_instance,
        terminated_ec2_instance
      ]
    end

    let(:asg_instances) do
      [
        instance_double(
          Aws::AutoScaling::Instance,
          instance_id: stopping_ec2_instance.instance_id,
          lifecycle_state: 'InService'
        ),
        instance_double(
          Aws::AutoScaling::Instance,
          instance_id: stopped_ec2_instance.instance_id,
          lifecycle_state: 'InService'
        ),
        instance_double(
          Aws::AutoScaling::Instance,
          instance_id: terminated_ec2_instance.instance_id,
          lifecycle_state: 'Terminated'
        )
      ]
    end

    before(:each) do
      ec2_instances.each do |i|
        allow(Aws::EC2::Instance).to(
          receive(:new).with(i.instance_id).and_return(i)
        )
        allow(i).to receive(:load)
        allow(i).to receive(:wait_until_stopped)
      end
    end

    it 'terminates instances in stopping or stopped state' do
      expect(ilog).to receive(:start_threaded).with(
        'Rotating ASG instances...'
      )
      ilog.start_threaded('Rotating ASG instances...') do |step|
        @step = step
        expect(stopping_ec2_instance).to receive(:terminate).once
        expect(stopped_ec2_instance).to receive(:terminate).once
        expect(terminated_ec2_instance).not_to receive(:terminate)
        subject.terminate_instances(asg_instances)
      end
    end
  end

  describe '#instance_in_terminal_state?' do
    subject { described_class.new(resources).send(:instance_in_terminal_state?, terminated_ec2_instance) }
    
    context 'when an ec2 instance object is nil' do
      let(:terminated_ec2_instance) do
        Aws::EC2::Instance.new(id: "i-123456")
      end

      before(:each) do
        allow(terminated_ec2_instance).to receive(:exists?).and_return(false)
      end

      it 'should send true for  state for nil instance object.' do
        expect(subject).to match(true)
      end
    end

    context 'when an asg instance object is nil' do
      let(:terminated_ec2_instance) do
        Aws::AutoScaling::Instance.new(id: "i-123456", group_name: "rspec-asg-group")
      end

      before(:each) do
        allow(terminated_ec2_instance).to receive(:load)
        allow(terminated_ec2_instance.load).to receive(:data)
      end

      it 'should send true for  state for nil instance object.' do
        expect(subject).to match(true)
      end
    end
  end
end
