describe Moonshot::Plugins::Backup do
  let(:hooks) do
    [
      :pre_create,
      :post_create,
      :pre_update,
      :post_update,
      :pre_delete,
      :post_delete,
      :pre_status,
      :post_status,
      :pre_doctor,
      :post_doctor
    ]
  end

  describe '#new' do
    subject { Moonshot::Plugins::Backup }

    it 'should yield self' do
      backup = subject.new do |b|
        b.bucket = 'test'
        b.files = %w(sample files)
        b.hooks = [:sample, :hooks]
      end
      expect(backup.bucket).to eq('test')
      expect(backup.files).to eq(%w(sample files))
      expect(backup.hooks).to eq([:sample, :hooks])
    end

    it 'should raise ArgumentError if insufficient parameters are provided' do
      expect { subject.new }.to raise_error(ArgumentError)
    end

    it 'should raise ArgumentError if redundant parameters are provided' do
      expect do
        subject.new do |b|
          b.bucket = 'test'
          b.buckets = {}
          b.files = %w(sample files)
          b.hooks = [:sample, :hooks]
        end
      end.to raise_error(ArgumentError)
    end

    let(:backup) do
      subject.new do |b|
        b.bucket = 'testbucket'
        b.files = %w(test files)
        b.hooks = [:post_create, :post_update]
      end
    end
    it 'should set a default value to target_name if not specified' do
      expect(backup.target_name).to eq '%{app_name}_%{timestamp}_%{user}.tar.gz'
    end
  end

  describe '#to_backup' do
    let(:test_bucket_name) { 'test_bucket' }
    let(:registered_hooks) { [:post_create, :post_update] }
    let(:unregistered_hooks) { hooks - registered_hooks }

    subject { Moonshot::Plugins::Backup.to_bucket(test_bucket_name) }

    it 'should return a Backup object' do
      expect(subject).to be_a Moonshot::Plugins::Backup
    end

    it 'should raise ArgumentError when no bucket specified' do
    end

    it 'should set default config values' do
      expect(subject.bucket).to eq test_bucket_name
      expect(subject.files).to eq [
        'cloud_formation/%{app_name}.json',
        'cloud_formation/parameters/%{stack_name}.yml'
      ]
      expect(subject.hooks).to eq [:post_create, :post_update]
    end

    it 'should only respond to the default hooks' do
      expect(subject).to respond_to(*registered_hooks)
      expect(subject).not_to respond_to(*unregistered_hooks)
    end
  end

  describe '#backup' do
    subject do
      Moonshot::Plugins::Backup.new do |b|
        b.buckets = {
          'dev_account' => 'dev_bucket'
        }
        b.files = ['test_file']
        b.hooks = %i(post_create post_update)
      end
    end

    let(:resources) do
      instance_double(
        Moonshot::Resources,
        stack: instance_double(Moonshot::Stack, app_name: 'test_app_name', name: 'test_name'),
        ilog: instance_double(Moonshot::InteractiveLoggerProxy)
      )
    end

    it 'should raise ArgumentError if resources are not injected' do
      expect { subject.backup }.to raise_error(ArgumentError)
    end

    it 'should return silent if account not found in buckets hash' do
      allow(subject).to receive(:iam_account).and_return('prod_account')
      expect(resources).not_to receive(:ilog)
      subject.backup(resources)
    end

    it 'should upload' do
      allow(subject).to receive(:iam_account).and_return('dev_account')
      expect(resources).to receive(:ilog).and_return(MockInteractiveLogger.new)

      %i(tar zip upload).each do |s|
        allow(subject).to receive(s)
        expect(subject).to receive(s)
      end

      subject.backup(resources)
    end
  end
end
