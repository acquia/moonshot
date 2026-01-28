# frozen_string_literal: true

require 'moonshot'

describe 'Moonshot SSM features' do
  let(:ssm_config) { Moonshot::SSMConfig.new }
  let(:instance_id) { 'i-1234567890abcdef0' }
  
  describe 'Moonshot::SSMCommandBuilder' do
    subject { Moonshot::SSMCommandBuilder.new(ssm_config, instance_id) }
    
    it 'builds a command result with instance_id' do
      result = subject.build('echo hello')
      expect(result.cmd).to eq('echo hello')
      expect(result.instance_id).to eq(instance_id)
    end
  end
  
  describe 'Moonshot::SSMForkExecutor' do
    let(:ssm_client) { instance_double(Aws::SSM::Client) }
    let(:command_id) { 'cmd-12345' }
    
    subject { Moonshot::SSMForkExecutor.new }
    
    before do
      allow(Aws::SSM::Client).to receive(:new).and_return(ssm_client)
    end
    
    it 'executes a command via SSM and returns output' do
      send_response = double(
        command: double(command_id: command_id)
      )
      
      invocation_response = double(
        status: 'Success',
        response_code: 0,
        standard_output_content: 'command output'
      )
      
      expect(ssm_client).to receive(:send_command).with(
        instance_ids: [instance_id],
        document_name: 'AWS-RunShellScript',
        parameters: { 'commands' => ['echo hello'] },
        timeout_seconds: 600
      ).and_return(send_response)
      
      expect(ssm_client).to receive(:get_command_invocation).with(
        command_id: command_id,
        instance_id: instance_id
      ).and_return(invocation_response).twice
      
      result = subject.run('echo hello', instance_id)
      
      expect(result.output).to eq('command output')
      expect(result.exitstatus).to eq(0)
    end
    
    it 'handles command failures' do
      send_response = double(
        command: double(command_id: command_id)
      )
      
      invocation_response = double(
        status: 'Failed',
        response_code: 1,
        standard_output_content: 'error output'
      )
      
      expect(ssm_client).to receive(:send_command).and_return(send_response)
      expect(ssm_client).to receive(:get_command_invocation)
        .and_return(invocation_response).twice
      
      result = subject.run('failing command', instance_id)
      
      expect(result.output).to eq('error output')
      expect(result.exitstatus).to eq(1)
    end
  end
  
  describe 'connection_method configuration' do
    it 'defaults to SSM' do
      config = Moonshot::ControllerConfig.new
      expect(config.connection_method).to eq(:ssm)
    end
    
    it 'can be set to SSH' do
      config = Moonshot::ControllerConfig.new
      config.connection_method = :ssh
      expect(config.connection_method).to eq(:ssh)
    end
  end
end
