describe Moonshot::Commands::Update do
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
end
