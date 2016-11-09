describe Moonshot::Command do
  describe '#parser' do
    subject { described_class.new.parser }

    it 'should work' do
      allow(described_class).to receive(:usage)
      subject.parse('-v')
    end
  end
end
