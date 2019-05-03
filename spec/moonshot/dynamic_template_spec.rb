require 'moonshot'

describe Moonshot::DynamicTemplate do
  include FakeFS::SpecHelpers

  let(:source_path) { 'spec_template.erb' }
  let(:parameters) { { test_param: 'test-value' } }
  let(:destination_path) { 'spec_template.json' }

  let(:source_content) do
    '{ "TestJsonKey": "<%= test_param %>" }'
  end

  let(:test_object) do
    described_class.new(
      source: source_path,
      parameters: parameters,
      destination: destination_path
    )
  end

  let(:cf_client) do
    instance_double(
      Aws::CloudFormation::Client,
      validate_template: nil
    )
  end

  before(:each) do
    File.write(source_path, source_content)
    allow(Aws::CloudFormation::Client).to receive(:new).and_return(cf_client)
  end

  describe '#process' do
    subject { test_object.process }

    after(:each) { subject }

    it 'should validate that the destination file does not exist' do
      expect(test_object).to receive(:validate_destination_exists)
    end

    it 'should process the template' do
      expect(test_object).to receive(:generate_template).and_call_original
    end

    it 'should validate the created template' do
      expect(test_object).to receive(:validate_template)
    end

    it 'should persist the generated template' do
      expect(test_object).to receive(:write_output)
    end
  end

  describe '#validate_destination_exists' do
    subject { test_object.send(:validate_destination_exists) }

    before(:each) { FileUtils.touch(destination_path) }

    it 'should raise an exception if the destination file exists' do
      expect { subject }.to raise_error(
        Moonshot::TemplateExists,
        /Output file '#{destination_path}' already exists./
      )
    end
  end

  describe '#validate_template' do
    before(:each) do
      allow(cf_client).to receive(:validate_template).and_raise(
        Aws::CloudFormation::Errors::ValidationError.new(nil, nil)
      )
    end

    it 'should raise an exception if the tempalte is invalid' do
      expect do
        test_object.send(:validate_template, '')
      end.to raise_error(
        Moonshot::InvalidTemplate,
        /Invalid template:\nAws::CloudFormation::Errors::ValidationError.*/
      )
    end
  end
end
