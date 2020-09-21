describe Moonshot::ASG do
  let(:name) { 'cdb-worker-dev-jarmes-WorkerASG-Q7DYM7901RBY' }
  let(:instance_id) { 'i-585e91dc' }
  let(:instance_id_2) { 'i-685e91dc' }
  let(:system) { instance_double(System) }
  let(:resources) do
    instance_double(
      Moonshot::Resources,
      stack: instance_double(
        Moonshot::Stack,
        name: 'test_name',
        parameters: {}
      ),
      ilog: instance_double(Moonshot::InteractiveLoggerProxy),
      controller: instance_double(
        Moonshot::Controller,
        config: instance_double(Moonshot::ControllerConfig, app_name: 'test')
      )
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

  before(:each) do
    allow(System).to receive(:new)
      .and_return(system)
    stub_cf_client
  end

  def stub_cf_client
    @cf_client = instance_double(Aws::CloudFormation::Client)
    allow(Aws::CloudFormation::Client).to receive(:new) do
      assert_aws_retry_limit
      @cf_client
    end
    allow(@cf_client).to receive(:validate_template).and_return(true)
  end

  subject do
    described_class.new(resources)
  end

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

  describe '#initialize' do
    before(:each) do
      allow(System).to receive(:new)
        .and_return(system)
      stub_cf_client
    end
    context 'when MOONSHOT_SSH_USER is not defined' do
      it 'uses LOGNAME for ssh_user' do
        ENV['LOGNAME'] = 'SemiCoolDude'
        ENV.delete('MOONSHOT_SSH_USER')
        expect(subject.instance_variable_get(:@ssh_user))
          .to eq('SemiCoolDude')
      end
    end

    context 'when MOONSHOT_SSH_USER is defined' do
      it 'uses MOONSHOT_SSH_USER for ssh_user' do
        ENV['MOONSHOT_SSH_USER'] = 'CoolDude'
        expect(subject.instance_variable_get(:@ssh_user))
          .to eq('CoolDude')
      end
    end
  end

  describe '#shutdown_instance' do
    let(:hostname) { 'ec2-54-236-102-14.compute-1.amazonaws.com' }
    let(:instance) { instance_double(Aws::EC2::Instance) }
    subject { super().send(:shutdown_instance, instance_id) }

    before(:each) do
      allow(Aws::EC2::Instance).to receive(:new).and_return(instance)
      allow(instance).to receive(:public_dns_name) \
        .and_return(hostname)
      allow(System).to receive(:exec)
    end

    it 'looks up the DNS name of the host' do
      expect(instance).to receive(:public_dns_name) \
        .and_return(hostname)
      subject
    end

    it 'issues a shutdown to the instance' do
      ENV['MOONSHOT_SSH_USER'] = 'ci_user'
      expect(System).to receive(:exec).with(
        /ssh (.*) ci_user@#{hostname} 'sudo shutdown -h now'/,
        raise_on_failure: false
      )
      subject
    end

    it 'runs SSH with proper option to ignore host keys' do
      ENV['MOONSHOT_SSH_USER'] = 'ci_user'
      opts_string = '-o UserKnownHostsFile=/dev/null ' \
                    '-o StrictHostKeyChecking=no'
      expect(System).to receive(:exec).with(
        /#{opts_string}/,
        any_args
      )
      subject
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
end
