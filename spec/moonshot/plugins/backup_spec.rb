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
    subject { Moonshot::Plugins::Backup.to_bucket bucket: 'bucket' }

    let(:resources) do
      instance_double(
        Moonshot::Resources,
        stack: instance_double(Moonshot::Stack),
        ilog: instance_double(Moonshot::InteractiveLoggerProxy)
      )
    end

    it 'should raise ArgumentError if resources not injected' do
      expect { subject.backup }.to raise_error(ArgumentError)
    end
  end
end
