describe 'create' do
  include_context 'with a CloudFormation stubbed client'

  let(:config) { Moonshot::ControllerConfig.new }
  subject { Moonshot::Controller.new(config) }

  let(:stack) { instance_double(Moonshot::Stack) }
  let(:ask_user_source) { instance_double(Moonshot::AskUserSource) }

  let(:cf_client_stubs) do
    {
      describe_stacks: {
        stacks: [
          {
            stack_name: 'parent-stack-1',
            creation_time: Time.now,
            stack_status: 'CREATE_COMPLETE',
            outputs: [
              { output_key: 'InputParameter2', output_value: 'Parent2' },
              { output_key: 'InputParameter3', output_value: 'Parent3' }
            ]
          }
        ]
      }
    }
  end

  before(:each) do
    expect(Moonshot::Stack).to receive(:new).and_return(stack)

    expect(stack).to receive(:template)
      .and_return(Moonshot::YamlStackTemplate.new(fixture_path('create1.yml')))

    subject.config.default_parameter_source = ask_user_source
  end

  # Scenario:
  #
  #                  Default | Parent | Answer | Override
  # InputParameter1     X
  # InputParameter2     X        X        X
  # InputParameter3              X
  # InputParameter4                       X         X
  #
  # The rightmost provided value should be used.
  context 'when parent, answer and overrides are all provided' do
    it 'use parameter precedent correctly.' do
      subject.config.parent_stacks = ['parent-stack-1']
      subject.config.answer_file   = fixture_path('answer1.yml')
      subject.config.parameter_overrides['InputParameter4'] = 'Override4'

      expect(ask_user_source).to receive(:get) do |sp|
        expect(sp.name).to eq('InputParameter1')
      end

      expect(stack).to receive(:create).and_return(true)

      subject.create

      pc = subject.config.parameters
      expect(pc.keys).to eq(%w(InputParameter1 InputParameter2 InputParameter3 InputParameter4))

      expected_create_stack_parameters = [
        { parameter_key: 'InputParameter1', parameter_value: 'Default1' },
        { parameter_key: 'InputParameter2', parameter_value: 'Answer2' },
        { parameter_key: 'InputParameter3', parameter_value: 'Parent3' },
        { parameter_key: 'InputParameter4', parameter_value: 'Override4' }
      ]
      expect(pc.values.map(&:to_cf)).to eq(expected_create_stack_parameters)
    end
  end

  # Scenario:
  #
  #                  Default | Parent | Answer | Override
  # InputParameter1     X
  # InputParameter2     X        X
  # InputParameter3              X
  # InputParameter4  ( <-- Not provided )
  context 'when some parameters are missing, but have no defaults' do
    it 'should raise an error' do
      subject.config.parent_stacks = ['parent-stack-1']
      subject.config.interactive = false
      expect(stack).not_to receive(:create)

      expect(ask_user_source).to receive(:get).ordered do |sp|
        expect(sp.name).to eq('InputParameter1')
      end
      expect(ask_user_source).to receive(:get).ordered do |sp|
        expect(sp.name).to eq('InputParameter4')
      end

      expect { subject.create }
        .to raise_error(RuntimeError, 'The following parameters were not provided: InputParameter4')

      pc = subject.config.parameters
      expect(pc.keys).to eq(%w(InputParameter1 InputParameter2 InputParameter3 InputParameter4))

      expect(pc['InputParameter1'].default?).to eq(true)
      expect(pc['InputParameter1'].set?).to eq(false)
      expect(pc['InputParameter1'].value).to eq('Default1')

      expect(pc['InputParameter2'].default?).to eq(true)
      expect(pc['InputParameter2'].set?).to eq(true)
      expect(pc['InputParameter2'].value).to eq('Parent2')

      expect(pc['InputParameter3'].default?).to eq(false)
      expect(pc['InputParameter3'].set?).to eq(true)
      expect(pc['InputParameter3'].value).to eq('Parent3')

      expect(pc['InputParameter4'].default?).to eq(false)
      expect(pc['InputParameter4'].set?).to eq(false)
      expect { pc['InputParameter4'].value }.to raise_error(RuntimeError)
    end
  end
end

describe 'update' do
  include_context 'with a CloudFormation stubbed client'

  let(:config) { Moonshot::ControllerConfig.new }
  subject { Moonshot::Controller.new(config) }

  let(:stack) { instance_double(Moonshot::Stack) }

  before(:each) do
    expect(Moonshot::Stack).to receive(:new).and_return(stack)

    expect(stack).to receive(:template)
      .and_return(Moonshot::YamlStackTemplate.new(fixture_path('create1.yml')))
  end

  # Scenario:
  #
  # Existing stack: InputParameter1, InputParameter2, InputParameter3
  # New Template: InputParameter1, InputParameter2, InputParameter3, InputParameter4
  #                  Default | UsePrevious | AnswerFile | Override
  # InputParameter1     X            X
  # InputParameter2                  X
  # InputParameter3                  X            X ( <-- New value from answer file )
  # InputParameter4                               X           X ( <-- CLI value and Answer value for new parameter)
  #
  # The rightmost provided value should be used.
  context 'when a new parameter is added to the stack with a template' do
    it 'use parameter precedent correctly.' do
      subject.config.answer_file = fixture_path('answer2.yml')
      subject.config.parameter_overrides['InputParameter4'] = 'Override4'

      existing_parameters = {
        'InputParameter1' => 'Existing1',
        'InputParameter2' => 'Existing2',
        'InputParameter3' => 'Existing3'
      }
      expect(stack).to receive(:parameters).and_return(existing_parameters)
      expect(stack).to receive(:update)
      subject.update(dry_run: false, force: false, refresh_parameters: false)

      pc = subject.config.parameters
      expect(pc.keys).to eq(%w(InputParameter1 InputParameter2 InputParameter3 InputParameter4))

      expected_update_stack_parameters = [
        { parameter_key: 'InputParameter1', use_previous_value: true },
        { parameter_key: 'InputParameter2', use_previous_value: true },
        { parameter_key: 'InputParameter3', parameter_value: 'Answer3' },
        { parameter_key: 'InputParameter4', parameter_value: 'Override4' }
      ]
      expect(pc.values.map(&:to_cf)).to eq(expected_update_stack_parameters)
    end
  end

  context 'when refresh-parameters option is provided' do
    before(:each) do
      subject.config.answer_file = fixture_path('answer2.yml')
      subject.config.parameter_overrides['InputParameter4'] = 'Override4'

      existing_parameters = {
        'InputParameter1' => 'Existing1',
        'InputParameter2' => 'Existing2',
        'InputParameter3' => 'Existing3'
      }
      expect(stack).to receive(:parameters).and_return(existing_parameters)
      expect(stack).to receive(:update)
    end

    it 'should preserve existing existing parent parameters' do
      expect_any_instance_of(Moonshot::ParentStackParameterLoader).to receive(:load_missing_only!)
      subject.update(dry_run: false, force: false, refresh_parameters: false)
    end

    it 'should refresh all parent stack parameters' do
      expect_any_instance_of(Moonshot::ParentStackParameterLoader).to receive(:load!)
      subject.update(dry_run: false, force: false, refresh_parameters: true)
    end
  end
end
