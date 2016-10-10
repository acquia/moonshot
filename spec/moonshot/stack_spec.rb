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
      let(:parent_stacks) { [] }
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
          capabilities: ['CAPABILITY_IAM']
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

    context 'when a parent stack is specified' do
      let(:parent_stacks) { ['myappdc-dc1'] }
      let(:cf_client) do
        stubs = {
          describe_stacks: {
            stacks: [
              {
                stack_name: 'myappdc-dc1',
                creation_time: Time.now,
                stack_status: 'CREATE_COMPLETE',
                outputs: [
                  { output_key: 'Parent1', output_value: 'parents value' },
                  { output_key: 'Parent2', output_value: 'other value' }
                ]
              }
            ]
          }
        }
        Aws::CloudFormation::Client.new(stub_responses: stubs)
      end
      let(:expected_create_stack_options) do
        {
          stack_name: 'rspec-app-staging',
          template_body: an_instance_of(String),
          tags: [
            { key: 'moonshot_application', value: 'rspec-app' },
            { key: 'moonshot_environment', value: 'staging' }
          ],
          parameters: [
            { parameter_key: 'Parent1', parameter_value: 'parents value' }
          ],
          capabilities: ['CAPABILITY_IAM']
        }
      end

      context 'when local yml file contains the override already' do
        it 'should import outputs as paramters for this stack' do
          expect(cf_client).to receive(:create_stack)
            .with(hash_including(expected_create_stack_options))
          subject.create

          expect(File.exist?('/cloud_formation/parameters/rspec-app-staging.yml')).to eq(true)
          yaml_data = subject.overrides
          expected_data = {
            'Parent1' => 'parents value'
          }
          expect(yaml_data).to match(expected_data)
        end
      end

      context 'when the local yml file does not contain the override' do
        it 'should import outputs as paramters for this stack' do
          File.open('/cloud_formation/parameters/rspec-app-staging.yml', 'w') do |fp|
            data = {
              'Parent1' => 'Existing Value!'
            }
            YAML.dump(data, fp)
          end
          expected_create_stack_options[:parameters][0][:parameter_value] = 'Existing Value!'
          expect(cf_client).to receive(:create_stack)
            .with(hash_including(expected_create_stack_options))
          subject.create

          expect(File.exist?('/cloud_formation/parameters/rspec-app-staging.yml')).to eq(true)
          yaml_data = subject.overrides
          expected_data = {
            'Parent1' => 'Existing Value!'
          }
          expect(yaml_data).to match(expected_data)
        end
      end
    end
  end

  describe '#template_file' do
    it 'should return the template file path' do
      path = File.join(Dir.pwd, 'cloud_formation', 'rspec-app.json')
      expect(subject.template_file).to eq(path)
    end
  end

  describe '#parameters_file' do
    it 'should return the parameters file path' do
      path = File.join(Dir.pwd, 'cloud_formation', 'parameters', 'rspec-app-staging.yml')
      expect(subject.parameters_file).to eq(path)
    end
  end

  describe '#template' do
    let(:yaml_path) { File.join(Dir.pwd, 'cloud_formation', 'rspec-app.yml') }
    let(:json_path) { File.join(Dir.pwd, 'cloud_formation', 'rspec-app.json') }

    context 'when there is a template file in both formats' do
      it 'should prefer the JSON formatted template file' do
        expect(subject.template).to be_an_instance_of(Moonshot::JsonStackTemplate)
      end
    end

    context 'when there is only one kind of template file available' do
      it 'should pick the JSON template file by default' do
        FakeFS::File.delete(yaml_path)
        expect(subject.template).to be_an_instance_of(Moonshot::JsonStackTemplate)
      end

      it 'should fall back to YAML if no JSON template was found' do
        FakeFS::File.delete(json_path)
        expect(subject.template).to be_an_instance_of(Moonshot::YamlStackTemplate)
      end
    end

    context 'when there is no template file available' do
      it 'should raise RuntimeError' do
        [yaml_path, json_path].each { |p| FakeFS::File.delete(p) }

        expect { subject.template }.to raise_error(RuntimeError)
      end
    end
  end
end
