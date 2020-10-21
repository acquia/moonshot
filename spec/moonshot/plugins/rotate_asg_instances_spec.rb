describe Moonshot::Plugins::RotateAsgInstances do
  let(:instance_id) { 'i-585e91dc' }
  let(:result) { Struct.new(:output, :error, :exitstatus) }
  let(:validation_error) do
    Moonshot::RotateAsgInstances::SSHValidationError.new(
      result.new('Output', 'Failure', 255)
    )
  end
  let(:successful_response) { result.new('Output', 'No Failure', 0) }
  let(:moonshot_config) { Moonshot::ControllerConfig.new }
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

  subject { described_class.new }

  let(:ssh) { Moonshot::RotateAsgInstances::SSH }

  before(:each) do
    subject.instance_variable_set(:@resources, resources)
    expect_any_instance_of(Moonshot::SSHTargetSelector).to receive(:choose!).and_return(instance_id)
  end

  describe '#doctor' do
    it 'raises error if check is not passed' do
      allow_any_instance_of(ssh).to receive(:test_ssh_connection).with(instance_id).and_raise(validation_error)
      expect{ subject.send(:doctor_check_ssh) }.to raise_error(Moonshot::DoctorCritical)
    end

    it 'does not raise error when check is passed' do
      allow_any_instance_of(ssh).to receive(:test_ssh_connection).with(instance_id).and_return(successful_response)
      expect{ subject.send(:doctor_check_ssh) }.not_to raise_error
    end
  end
end
