describe Moonshot::Plugins::Cleaner do
  include_context 'with a working moonshot application'
  let(:resources) do
    instance_double(
      Moonshot::Resources,
      stack: instance_double(Moonshot::Stack, app_name: 'test_app_name', name: 'test_name'),
      ilog: instance_double(Moonshot::InteractiveLoggerProxy)
    )
  end

  before(:all) do
    # Using doubles without context is unsupported. with_temporary_scope to the rescue.
    RSpec::Mocks.with_temporary_scope do
      allow(Aws::S3::Client).to receive(:new).and_return(instance_double(Aws::S3::Client))
    end
  end

  subject do
    described_class.new('bucket')
  end

  describe '#new' do
    it 'should raise ArgumentError if insufficient parameters are provided' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end

  describe '#list_objects' do
    it 'should return with the correct names if a search prefix is provided' do
      contents = [{ key: 'file1.tar.gz' }, { key: 'file2.tar.gz' }]
      Aws.config[:s3] = {
        stub_responses: {
          list_objects: { contents: contents }
        }
      }
      expect(subject.retrieve_artifact_names('file1')).to eq(['file1.tar.gz'])
    end

    it 'it should not fail if no artifacts are found' do
      contents = [{ key: 'file1.tar.gz' }, { key: 'file2.tar.gz' }]
      Aws.config[:s3] = {
        stub_responses: {
          list_objects: { contents: contents }
        }
      }
      expect(subject.retrieve_artifact_names('liludalas')).to eq([])
    end
  end

  describe '#delete_artifacts' do
    it 'should log an error message if the delete operation failed' do
      subject.resources = resources
      contents = [{ key: 'Error1', version_id: '1', code: '1', message: 'failed' }]
      Aws.config[:s3] = {
        stub_responses: {
          delete_objects: { errors: contents }
        }
      }
      expect(resources.ilog).to receive(:error)
      subject.delete_artifacts(['liludalas'])
    end

    it 'should not log an error message in case the delete was successful' do
      subject.resources = resources
      contents = [{ key: 'file1', version_id: '1' }]
      Aws.config[:s3] = {
        stub_responses: {
          delete_objects: { deleted: contents }
        }
      }
      expect(resources.ilog).not_to receive(:error)
      subject.delete_artifacts(['file1'])
    end
  end

  describe '#post_delete' do
    let(:step) { instance_double('InteractiveLogger::Step') }

    it 'post_delete should inform what it deleted from where' do
      expect(resources.ilog).to receive(:start).and_yield(step)
      expect(step).to receive(:success)
        .with('Deleted artifacts for stack: ' \
              "'#{resources.stack.name}' in bucket: 'bucket'")
      expect(subject).to receive(:retrieve_artifact_names).with(resources.stack.name)
        .and_return(['test_name'])
      subject.post_delete(resources)
    end

    it 'post_delete should inform if nothing was deleted' do
      expect(resources.ilog).to receive(:start).and_yield(step)
      expect(step).to receive(:success).with('No artifacts found, nothing to delete.')
      expect(subject).to receive(:retrieve_artifact_names).with(resources.stack.name)
        .and_return([])
      subject.post_delete(resources)
    end
  end
end
