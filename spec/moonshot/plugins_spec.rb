class MockPlugin
  def pre_create
  end

  def post_create
  end
end

describe 'the Moonshot::CLI interface to plugins' do
  let(:controller) { instance_double('Moonshot::Controller') }

  subject do
    Class.new(Moonshot::CLI) do
      self.application_name = 'my-app'
      plugin MockPlugin.new
      plugin MockPlugin.new
    end
  end

  it 'sets the plugins provided to Moonshot::Controller' do
    config = Moonshot::ControllerConfig.new
    expect(Moonshot::Controller).to receive(:new).and_yield(config).and_return(controller)
    expect(controller).to receive(:status)

    subject.start(['status'])
    expect(config.plugins.size).to eq(2)
  end
end

describe 'Plugins support' do
  let(:plugin1) { MockPlugin.new }
  let(:plugin2) { MockPlugin.new }

  let(:stack) { instance_double('Moonshot::Stack') }

  subject do
    Moonshot::Controller.new do |config|
      config.app_name = 'my-app'
      config.plugins = [plugin1, plugin2]
      config.logger = Logger.new(nil)
    end
  end

  before(:each) do
    expect(Moonshot::Stack).to receive(:new).and_return(stack)
  end

  it 'calls defined methods on plugins in order, providing them with a Moonshot::Resources' do
    expect(plugin1).to receive(:pre_create).with(an_instance_of(Moonshot::Resources)).ordered
    expect(plugin2).to receive(:pre_create).with(an_instance_of(Moonshot::Resources)).ordered
    expect(stack).to receive(:create).ordered.and_return(true)
    expect(plugin1).to receive(:post_create).with(an_instance_of(Moonshot::Resources)).ordered
    expect(plugin2).to receive(:post_create).with(an_instance_of(Moonshot::Resources)).ordered

    subject.create
  end

  it "doesn't call an undefined method" do
    expect(stack).to receive(:delete)

    # The assertion here is that calling MockPlugin#pre_delete would cause an
    # exception. Using an expect().not_to receive() changes the behavior of
    # #respond_to?, so we can't write that expectation.
    expect { subject.delete }
      .not_to raise_error
  end
end
