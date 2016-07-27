describe Moonshot::Plugins::Cleaner do
  include_context 'with a working moonshot application'

  let(:ilog) { Moonshot::InteractiveLoggerProxy.new(log) }
  let(:log) { instance_double('Logger').as_null_object }
  let(:parent_stacks) { [] }
  let(:cf_client) { instance_double(Aws::CloudFormation::Client) }

  subject { Moonshot::Plugins::Cleaner }

  before(:each) do
    allow(Aws::CloudFormation::Client).to receive(:new).and_return(cf_client)
  end

  describe '#post_delete' do

    it 'post_delete should return stack name' do
      expect(subject).to receive(:post_delete).and_return('asdf')
      expect(subject.send(:post_delete)).to eq('asdf')
    end
  end
end
