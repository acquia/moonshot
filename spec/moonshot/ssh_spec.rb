describe 'Moonshot SSH features' do
  subject do
    c = Moonshot::ControllerConfig.new
    c.app_name = 'MyApp'
    c.environment_name = 'prod'
    c.ssh_config.ssh_user = 'joeuser'
    c.ssh_command = 'cat /etc/passwd'
    Moonshot::Controller.new(c)
  end

  let(:stack_double) { instance_double(Moonshot::Stack, name: 'MyApp-prod') }

  describe 'Moonshot::Controller#ssh' do
    before(:each) do
      ENV.delete('MOONSHOT_SSH_OPTIONS')
      ENV['AWS_REGION'] = 'us-east-1'
      allow(subject).to receive(:stack).and_return(stack_double)
    end

    after(:each) do
      ENV.delete('AWS_REGION')
    end

    context 'normally' do
      it 'should execute a tsh ssh command with proper parameters' do
        ts = instance_double(Moonshot::SSHTargetSelector)
        expect(Moonshot::SSHTargetSelector).to receive(:new).and_return(ts)
        expect(ts).to receive(:choose!).and_return('i-04683a82f2dddcc04')

        expect(subject).to receive(:exec)
          .with('tsh ssh --proxy=us-east-1.teleport.cloudservices.acquia.io -tA joeuser@i-04683a82f2dddcc04.us-east-1.546349603759 cat\ /etc/passwd') # rubocop:disable LineLength
        expect { subject.ssh }
          .to output("Opening SSH connection to i-04683a82f2dddcc04 (i-04683a82f2dddcc04.us-east-1.546349603759)...\n")
          .to_stderr
      end
    end

    context 'when an instance id is given' do
      subject do
        c = super()
        c.config.ssh_instance = 'i-012012012012012'
        c
      end

      it 'should execute a tsh ssh command with proper parameters' do
        expect(subject).to receive(:exec)
          .with('tsh ssh --proxy=us-east-1.teleport.cloudservices.acquia.io -tA joeuser@i-012012012012012.us-east-1.546349603759 cat\ /etc/passwd') # rubocop:disable LineLength
        expect { subject.ssh }
          .to output("Opening SSH connection to i-012012012012012 (i-012012012012012.us-east-1.546349603759)...\n").to_stderr
      end
    end
  end
end
