describe 'Moonshot SSH features' do
  subject do
    Moonshot::Controller.new do |c|
      c.app_name = 'MyApp'
      c.environment_name = 'prod'
      c.ssh_config.ssh_user = 'joeuser'
      c.ssh_config.ssh_identity_file = '/Users/joeuser/.ssh/thegoods.key'
      c.ssh_command = 'cat /etc/passwd'
    end
  end

  describe 'Moonshot::Controller#ssh' do
    context 'normally' do
      it 'should execute an ssh command with proper parameters' do
        ts = instance_double(Moonshot::SSHTargetSelector)
        expect(Moonshot::SSHTargetSelector).to receive(:new).and_return(ts)
        expect(ts).to receive(:choose!).and_return('i-04683a82f2dddcc04')

        expect_any_instance_of(Moonshot::SSHCommandBuilder).to receive(:instance_ip).exactly(2)
          .and_return('123.123.123.123')
        expect(STDOUT).to receive(:puts)
          .with('Opening SSH connection to i-04683a82f2dddcc04 (123.123.123.123)...')
        expect(subject).to receive(:exec)
          .with('ssh -t -i /Users/joeuser/.ssh/thegoods.key -l joeuser 123.123.123.123 cat\ /etc/passwd') # rubocop:disable LineLength
        subject.ssh
      end
    end

    context 'when an instance id is given' do
      subject do
        c = super()
        c.config.ssh_instance = 'i-012012012012012'
        c
      end

      it 'should execute an ssh command with proper parameters' do
        expect_any_instance_of(Moonshot::SSHCommandBuilder).to receive(:instance_ip).exactly(2)
          .and_return('123.123.123.123')
        expect(STDOUT).to receive(:puts)
          .with('Opening SSH connection to i-012012012012012 (123.123.123.123)...')
        expect(subject).to receive(:exec)
          .with('ssh -t -i /Users/joeuser/.ssh/thegoods.key -l joeuser 123.123.123.123 cat\ /etc/passwd') # rubocop:disable LineLength
        subject.ssh
      end
    end
  end
end
