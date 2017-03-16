describe Moonshot::Plugins::CodeDeploySetup do
  subject { Moonshot::Plugins::CodeDeploySetup }

  describe '#new' do
    it 'should raise ArgumentError if no region arg is set' do
      allow(ENV).to receive(:[]).with("AWS_REGION").and_return(nil)
      expect { subject.new('example') }.to raise_error(ArgumentError)
    end

    it 'should use the ENV[AWS_REGION] if no region arg is set' do
      allow(ENV).to receive(:[]).with("AWS_REGION").and_return('us-west-2')
      expect(subject.new('example').regions).to include('us-west-2')
    end

    it 'should use return the correct bucket name for the current active region' do
      allow(ENV).to receive(:[]).with("AWS_REGION").and_return('ap-southeast-1')
      expect(subject.new('example-builds').bucket_name).to eq('example-builds-ap-southeast-1')
    end

    it 'should use return the correct bucket prefix' do
      allow(ENV).to receive(:[]).with("AWS_REGION").and_return('us-east-1')
      expect(subject.new('example-builds').bucket_prefix).to eq('')
      expect(subject.new('example-builds', prefix: 'api').bucket_prefix).to eq('api/')
    end
  end

  describe '#run_hook' do
    let(:s3_client) { instance_double(Aws::S3::Client) }
    let(:s3_bucket) { instance_double(Aws::S3::Bucket) }

    before(:each) do
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(Aws::S3::Bucket).to receive(:new).and_return(s3_bucket)
      allow(s3_bucket).to receive(:exists?).and_return(false)
      allow(s3_bucket).to receive(:create).and_return(true)
    end

    it 'creates a bucket for all set regions' do
      allow(ENV).to receive(:[]).with("AWS_REGION").and_return('us-east-1')
      plugin = subject.new('example')
      expect(plugin.regions).to include('us-east-1')
      expect(s3_bucket).to receive(:exists?)
      expect(s3_bucket).to receive(:create)

      plugin.pre_create(nil)
    end
  end
end
