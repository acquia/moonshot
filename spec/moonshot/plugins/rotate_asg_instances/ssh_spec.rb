describe Moonshot::RotateAsgInstances::SSH do
  let(:instance_id) { 'i-585e91dc' }
  let(:command) { '/bin/true' }
  let(:result) { Struct.new(:output, :error, :exitstatus) }
  let(:successful_response) { result.new('Output', 'No Failure', 0) }
  let(:validation_error) do
    Moonshot::RotateAsgInstances::SSHValidationError.new(
      result.new('Output', 'Failure', 255)
    )
  end
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

  let(:config) { resources.controller.config }

  subject { described_class.new }

  describe '#test_ssh_connection' do
    it 'raise error if #test_ssh_connection fails' do
      allow(subject).to receive(:test_ssh_connection).with(instance_id).and_raise(validation_error)
      expect { subject.test_ssh_connection(instance_id) }.to raise_error(validation_error)
    end

    it 'does not raise error if ssh is successful' do
      allow(subject).to receive(:test_ssh_connection).with(instance_id).and_return(successful_response)
      expect { subject.test_ssh_connection(instance_id) }.not_to raise_error
    end
  end

  describe '#exec' do
    it 'executes the command given' do
      allow(subject).to receive(:exec).with(command, instance_id).and_return(successful_response)
      expect(subject.exec(command, instance_id)).to eql(successful_response)
    end
  end
end
