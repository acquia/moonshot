require 'moonshot'
require_relative 'stub_rollout_asg'
String.disable_colorization = true

describe Moonshot::Tools::ASGRollout do
  def health(asg, elb)
    Moonshot::Tools::ASGRollout::InstanceHealth.new(asg, elb)
  end

  let(:moonshot_config) do
    c = Moonshot::ControllerConfig.new
    c.interactive_logger = MockInteractiveLogger.new
    c
  end

  let(:moonshot_stack) { instance_double('Moonshot::Stack') }

  let(:controller) do
    instance_double('Moonshot::Controller',
                    config: moonshot_config,
                    stack: moonshot_stack)
  end

  subject do
    described_class.new(controller: controller, logical_id: 'MyAutoScalingGroup') do |c|
      c.pre_detach = proc do |h|
        h.debug('This is a debug message from a pre-detach hook.')
        h.info('This is an info message from a pre-detach hook.')
        true
      end

      # Succeed the terminate_when check on the 5th interval.
      c.terminate_when = proc do |h|
        @n ||= 0
        @n += 1
        h.debug("Checking for terminatability #{@n}/5")
        if @n == 5
          @n = 0
          true
        else
          false
        end
      end

      # Don't actually call EC2.
      c.terminate = proc { true }

      c.terminate_when_delay = 0
      c.instance_health_delay = 0
    end
  end

  let(:asg) { StubRolloutASG.new }

  let(:asg_name) { 'my-auto-scaling-group-123123123' }

  before(:example) do
    expect(moonshot_stack).to receive(:physical_id_for).with('MyAutoScalingGroup')
      .and_return(asg_name)
    expect(Moonshot::Tools::ASGRollout::ASG).to receive(:new)
      .with(asg_name)
      .and_return(asg)

    # The environment has three instances, but the third is already on
    # the correct LaunchConfiguration.
    asg.add_instances(
      ['i-0000001', false],
      ['i-0000002', false],
      ['i-0000003', true]
    )

    # Both instances take three checks to arrive at Detached/Missing.
    asg.add_health_response('i-0000001',
                            %w(InService InService),
                            %w(Detaching InService),
                            %w(Detached Missing))

    asg.add_health_response('i-0000002',
                            %w(InService InService),
                            %w(Detaching InService),
                            %w(Detached Missing))

    # Instances are replaced with 2xxxxxY matching instances.
    asg.add_replacement_instances(
      ['i-2000001', true],
      ['i-2000002', true]
    )

    # Replacement instances are magically InService immediately.
    asg.add_health_response('i-2000001', %w(InService InService))
    asg.add_health_response('i-2000002', %w(InService InService))
  end

  let(:should_use_everything) { true }
  let(:should_be_successful) { true }
  after(:example) do
    expect(asg.everything_used?).to eq(should_use_everything)

    if should_be_successful
      expect(asg.instances.map(&:id).sort).to eq(['i-0000003', 'i-2000001', 'i-2000002'])
    end
  end

  context 'for a basic configuration' do
    it 'should perform the normal procedure' do
      expect { subject.run! }.not_to raise_error

      log_expectations = [
        [:success, 'Increased MaxSize/DesiredCapacity by 1.'],
        [:success, 'A wild i-2000001 appears!'],
        [:success, 'Instance i-2000001 is ASG:InService/ELB:InService!'],
        [:debug, 'This is a debug message from a pre-detach hook.'],
        [:info, 'This is an info message from a pre-detach hook.'],
        [:success, 'PreDetach hook complete for i-0000001!'],
        [:success, 'Detached instance i-0000001.'],
        [:success, 'Instance i-0000001 is ASG:Detached/ELB:Missing!'],
        [:success, 'A wild i-2000002 appears!'],
        [:success, 'Instance i-2000002 is ASG:InService/ELB:InService!'],
        [:debug, 'Checking for terminatability 1/5'],
        [:debug, 'Checking for terminatability 2/5'],
        [:debug, 'Checking for terminatability 3/5'],
        [:debug, 'Checking for terminatability 4/5'],
        [:debug, 'Checking for terminatability 5/5'],
        [:success, 'Completed TerminateWhen check for i-0000001!'],
        [:success, 'Terminated i-0000001!'],
        [:debug, 'This is a debug message from a pre-detach hook.'],
        [:info, 'This is an info message from a pre-detach hook.'],
        [:success, 'PreDetach hook complete for i-0000002!'],
        [:success, 'Detached instance i-0000002, and decremented DesiredCapacity.'],
        [:success, 'Instance i-0000002 is ASG:Detached/ELB:Missing!'],
        [:debug, 'Checking for terminatability 1/5'],
        [:debug, 'Checking for terminatability 2/5'],
        [:debug, 'Checking for terminatability 3/5'],
        [:debug, 'Checking for terminatability 4/5'],
        [:debug, 'Checking for terminatability 5/5'],
        [:success, 'Completed TerminateWhen check for i-0000002!'],
        [:success, 'Terminated i-0000002!'],
        [:success, 'Restored MaxSize/DesiredCapacity values to normal!']
      ]
      expect(moonshot_config.interactive_logger.final_logs).to eq(log_expectations)
    end
  end

  context 'when a TerminateWhen hook does not complete in the timeout' do
    subject do
      s = super()
      s.config.terminate_when_delay = 0.1
      s.config.terminate_when_timeout = 0.35
      s
    end

    let(:should_be_successful) { false }
    let(:should_use_everything) { true }

    it 'should fail' do
      expect { subject.run! }.not_to raise_error

      log_expectations = [
        [:success, 'Increased MaxSize/DesiredCapacity by 1.'],
        [:success, 'A wild i-2000001 appears!'],
        [:success, 'Instance i-2000001 is ASG:InService/ELB:InService!'],
        [:debug, 'This is a debug message from a pre-detach hook.'],
        [:info, 'This is an info message from a pre-detach hook.'],
        [:success, 'PreDetach hook complete for i-0000001!'],
        [:success, 'Detached instance i-0000001.'],
        [:success, 'Instance i-0000001 is ASG:Detached/ELB:Missing!'],
        [:success, 'A wild i-2000002 appears!'],
        [:success, 'Instance i-2000002 is ASG:InService/ELB:InService!'],
        [:debug, 'Checking for terminatability 1/5'],
        [:debug, 'Checking for terminatability 2/5'],
        [:debug, 'Checking for terminatability 3/5'],
        [:debug, 'Checking for terminatability 4/5'],
        [:failure, 'TerminateWhen for i-0000001 did not complete in 0.35 seconds!'],
        [:success, 'Terminated i-0000001!'],
        [:debug, 'This is a debug message from a pre-detach hook.'],
        [:info, 'This is an info message from a pre-detach hook.'],
        [:success, 'PreDetach hook complete for i-0000002!'],
        [:success, 'Detached instance i-0000002, and decremented DesiredCapacity.'],
        [:success, 'Instance i-0000002 is ASG:Detached/ELB:Missing!'],
        [:debug, "Checking for terminatability 5/5"],
        [:success, "Completed TerminateWhen check for i-0000002!"],
        [:success, 'Terminated i-0000002!'],
        [:success, 'Restored MaxSize/DesiredCapacity values to normal!']
      ]
      expect(moonshot_config.interactive_logger.final_logs).to eq(log_expectations)
    end
  end

  context 'when the pre-detach hook returns false' do
    before(:each) do
      subject.config.pre_detach = proc { false }
    end

    let(:should_use_everything) { false }
    let(:should_be_successful) { false }

    it 'should abort with a failure before detaching the instance' do
      expect { subject.run! }
        .to raise_error('PreDetach hook failed for i-0000001!')

      log_expectations = [
        [:success, 'Increased MaxSize/DesiredCapacity by 1.'],
        [:success, 'A wild i-2000001 appears!'],
        [:success, 'Instance i-2000001 is ASG:InService/ELB:InService!'],
        [:failure, 'PreDetach hook failed for i-0000001!'],
        [:success, 'Restored MaxSize/DesiredCapacity values to normal!']
      ]
      expect(moonshot_config.interactive_logger.final_logs).to eq(log_expectations)
    end
  end
end
