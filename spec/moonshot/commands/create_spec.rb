describe Moonshot::Commands::Create do
  before(:each) do
    Moonshot.config = Moonshot::ControllerConfig.new
  end

  tests = {
    %w(-P Key=Value -P OtherKey=OtherValue) => { 'Key' => 'Value', 'OtherKey' => 'OtherValue' },
    %w(-PKey=ValueWith=Equals) => { 'Key' => 'ValueWith=Equals' }
  }

  tests.each do |input, expected|
    it "Should process #{input} correctly" do
      op = subject.parser
      op.parse(input)
      expect(Moonshot.config.parameter_overrides).to match(expected)
    end
  end

  it 'should handle version and deploy correctly' do
    op = subject.parser
    op.parse(%w(--version 1.2.3 --no-deploy -P Key=Value))
    expect(subject.version).to eq('1.2.3')
    expect(subject.deploy).to eq(false)
    expect(Moonshot.config.parameter_overrides).to match('Key' => 'Value')
  end

  it 'should process multiple parent stacks' do
    op = subject.parser
    op.parse(%w(--parents parent1,parent2,parent3 --no-deploy))
    expect(subject.deploy).to eq(false)
    expect(Moonshot.config.parent_stacks.count).to be(3)
  end
end
