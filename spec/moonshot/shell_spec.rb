require 'securerandom'

module Moonshot
  describe Shell do
    include ResourcesHelper
    include described_class

    let(:resources) do
      Resources.new(
        ilog: InteractiveLoggerProxy.new(log),
        stack: double(Stack).as_null_object,
        controller: instance_double(Moonshot::Controller).as_null_object
      )
    end

    before { self.resources = resources }

    describe '#shell' do
      it 'should return a shell compatible with Thor::Shell::Basic.' do
        expect(shell).to be_a(Thor::Shell::Basic)
      end
    end

    describe '#sh_out' do
      it 'should raise on non-zero exit.' do
        expect { sh_out('false') }.to raise_error(/`false` exited 1/)
      end

      it 'should not raise if fail is disabled.' do
        sh_out('false', fail: false)
      end
    end

    describe '#sh_step' do
      before do
        expect(InteractiveLoggerProxy::Step).to receive(:new).and_return(step)
      end

      let(:step) { instance_double(InteractiveLoggerProxy::Step) }

      it 'should raise an error if the step fails.' do
        expect { sh_step('false') }.to raise_error(/`false` exited 1/)
      end

      it 'should provide the step and sh output to a block.' do
        output = nil
        expect(step).to receive(:continue).with('reticulating splines')
        expect(step).to receive(:success)
        sh_step('echo yo') do |step, out|
          step.continue('reticulating splines')
          output = out
        end
        expect(output).to match('yo')
      end

      it 'should truncate a long messages.' do
        long_s = SecureRandom.urlsafe_base64(terminal_width)
        cmd = "echo #{long_s}"
        truncated_s = "#{cmd[0..(terminal_width - 22)]}..."
        expect(resources.ilog).to receive(:start_threaded).with(truncated_s)
          .and_call_original
        allow(step).to receive(:success)
        sh_step(cmd)
      end
    end
  end
end
