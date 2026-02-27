describe Moonshot::TeleportConfig do
  let(:instance_id) { 'i-0036e48e43b79740f' }

  describe 'prod environment (stack name contains "prod")' do
    subject { described_class.new('myapp-prod-us-east-1', 'joeuser', 'us-east-1') }

    it 'uses region-based proxy URL' do
      expect(subject.proxy_url).to eq('us-east-1.teleport.cloudservices.acquia.io')
    end

    it 'uses the prod account ID' do
      expect(subject.account_id).to eq('546349603759')
    end

    it 'builds the Teleport hostname correctly' do
      expect(subject.host_for(instance_id)).to eq(
        'i-0036e48e43b79740f.us-east-1.546349603759'
      )
    end

    it 'is not a bot user for a normal user' do
      expect(subject.bot_user?).to be false
    end

    it 'returns nil identity_file for normal user' do
      expect(subject.identity_file).to be_nil
    end

    context 'with bot user (clouddatabot)' do
      subject { described_class.new('myapp-prod-us-east-1', 'clouddatabot', 'us-east-1') }

      it 'is identified as a bot user' do
        expect(subject.bot_user?).to be true
      end

      it 'uses the region-based identity file path' do
        expect(subject.identity_file).to eq('tbot-auth-us-east-1/identity')
      end
    end
  end

  describe 'dev environment (stack name does not contain "prod")' do
    subject { described_class.new('myapp-dev-jsmith', 'joeuser', 'us-east-1') }

    it 'uses the shared dev proxy URL' do
      expect(subject.proxy_url).to eq('teleport.dev.cloudservices.acquia.io')
    end

    it 'uses the dev account ID' do
      expect(subject.account_id).to eq('672327909798')
    end

    it 'builds the Teleport hostname correctly' do
      expect(subject.host_for(instance_id)).to eq(
        'i-0036e48e43b79740f.us-east-1.672327909798'
      )
    end

    it 'is not a bot user for a normal user' do
      expect(subject.bot_user?).to be false
    end

    context 'with bot user (clouddatabot)' do
      subject { described_class.new('myapp-dev-jsmith', 'clouddatabot', 'us-east-1') }

      it 'is identified as a bot user' do
        expect(subject.bot_user?).to be true
      end

      it 'uses the fixed clouddata-node identity file path' do
        expect(subject.identity_file).to eq('tbot-auth-clouddata-node/identity')
      end
    end
  end
end
