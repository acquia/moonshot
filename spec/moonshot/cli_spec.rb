require 'moonshot'

class AppWithAutoPrefix < Moonshot::CLI
  self.application_name = 'my-app'
end

class AppWithoutAutoPrefix < Moonshot::CLI
  self.auto_prefix_stack = false
  self.application_name = 'my-other-app'
end

class AppToTest < Moonshot::CLI
  self.application_name = 'my-app'
end

describe AppWithAutoPrefix do
  let(:stack) { instance_double(Moonshot::Stack) }
  before(:each) do
    expect(stack).to receive(:status)
    stub_const('ENV', 'USER' => 'rspec')
  end

  it 'should prepend the app name when not specified' do
    expect(Moonshot::Stack).to receive(:new)
      .with('my-app-stack1', an_instance_of(Hash)).and_return(stack)
    described_class.start('status -n stack1'.split)
  end

  it 'should not prepend the app name with already specified' do
    expect(Moonshot::Stack).to receive(:new)
      .with('my-app-stack1', an_instance_of(Hash)).and_return(stack)
    described_class.start('status -n my-app-stack1'.split)
  end
end

describe AppWithoutAutoPrefix do
  let(:stack) { instance_double(Moonshot::Stack) }
  before(:each) do
    expect(stack).to receive(:status)
    stub_const('ENV', 'USER' => 'rspec')
  end

  it 'should not prepend the app name when not specified' do
    expect(Moonshot::Stack).to receive(:new)
      .with('stack1', an_instance_of(Hash)).and_return(stack)
    described_class.start('status -n stack1'.split)
  end
  it 'should not prepend the app name when already specified' do
    expect(Moonshot::Stack).to receive(:new)
      .with('my-other-app-stack1', an_instance_of(Hash)).and_return(stack)
    described_class.start('status -n my-other-app-stack1'.split)
  end
end

describe AppToTest do
  before(:each) do
    stub_const('ENV', 'USER' => 'rspec')
  end

  it 'created a new controller object' do
    controller = instance_double(Moonshot::Controller)
    expect(Moonshot::Controller).to receive(:new).and_return(controller)
    described_class.new.controller
  end

  it 'can access stack by inheriting Moonshot::CLI' do
    expect(Moonshot::Stack).to receive(:new)
    described_class.new.controller.stack
  end
end
