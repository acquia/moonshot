describe Moonshot::Stack do
  include_context 'with a working moonshot application'

  let(:log) { instance_double('Logger').as_null_object }
  let(:ilog) { Moonshot::InteractiveLoggerProxy.new(log) }
  let(:parent_stacks) { [] }
  let(:cf_client) { instance_double(Aws::CloudFormation::Client) }

  let(:config) { Moonshot::ControllerConfig.new }
  before(:each) do
    config.app_name = 'rspec-app'
    config.environment_name = 'staging'
    config.interactive_logger = ilog
    config.parent_stacks = parent_stacks

    allow(Aws::CloudFormation::Client).to receive(:new).and_return(cf_client)
  end

  subject { described_class.new(config) }

  describe '#create' do
    let(:step) { instance_double('InteractiveLogger::Step') }
    let(:stack_exists) { false }

    before(:each) do
      expect(ilog).to receive(:start).and_yield(step)
      expect(subject).to receive(:stack_exists?).and_return(stack_exists)
      expect(step).to receive(:success)
    end

    context 'when the stack creation takes too long' do
      it 'should display a helpful error message and return false' do
        expect(subject).to receive(:create_stack)
        expect(subject).to receive(:wait_for_stack_state)
          .with(:stack_create_complete, 'created').and_return(false)
        expect(subject.create).to eq(false)
      end
    end

    context 'when the stack creation completes in the expected time frame' do
      it 'should log the process and return true' do
        expect(subject).to receive(:create_stack)
        expect(subject).to receive(:wait_for_stack_state)
          .with(:stack_create_complete, 'created').and_return(true)
        expect(subject.create).to eq(true)
      end
    end

    context 'when the stack already exists' do
      let(:stack_exists) { true }

      it 'should log a successful step and return true' do
        expect(subject).not_to receive(:create_stack)
        expect(subject.create).to eq(true)
      end
    end

    context 'under normal circumstances' do
      let(:expected_create_stack_options) do
        {
          stack_name: 'rspec-app-staging',
          template_body: an_instance_of(String),
          tags: [
            { key: 'moonshot_application', value: 'rspec-app' },
            { key: 'moonshot_environment', value: 'staging' },
            { key: 'ah_stage', value: 'rspec-app-staging' }
          ],
          parameters: [],
          capabilities: ['CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM']
        }
      end

      let(:cf_client) do
        stubs = {
          describe_stacks: {
            stacks: [
              {
                stack_name: 'rspec-app-staging',
                creation_time: Time.now,
                stack_status: 'CREATE_COMPLETE',
                outputs: []
              }
            ]
          }
        }
        Aws::CloudFormation::Client.new(stub_responses: stubs)
      end

      it 'should call CreateStack, then wait for completion' do
        config.additional_tag = 'ah_stage'
        expect(cf_client).to receive(:create_stack)
          .with(hash_including(expected_create_stack_options))
        subject.create
      end
    end
  end

  describe '#template_file' do
    it 'should return the template file path' do
      path = File.join(Dir.pwd, 'moonshot', 'template.yml')
      expect(subject.template_file).to eq(path)
    end
  end

  describe '#template' do
    let(:yaml_path) { File.join(Dir.pwd, 'moonshot', 'template.yml') }
    let(:json_path) { File.join(Dir.pwd, 'moonshot', 'template.json') }
    let(:yaml_legacy_path) { File.join(Dir.pwd, 'cloud_formation', 'rspec-app.yml') }
    let(:json_legacy_path) { File.join(Dir.pwd, 'cloud_formation', 'rspec-app.json') }

    it 'should look for templates in the preferred order' do
      expect(subject.template.filename).to eq(yaml_path)
      FakeFS::File.delete(yaml_path)
      expect(subject.template.filename).to eq(json_path)
      FakeFS::File.delete(json_path)
      expect(subject.template.filename).to eq(yaml_legacy_path)
      FakeFS::File.delete(yaml_legacy_path)
      expect(subject.template.filename).to eq(json_legacy_path)
      FakeFS::File.delete(json_legacy_path)
      expect { subject.template }
        .to raise_error(RuntimeError, /No template found/)
    end
  end
end
