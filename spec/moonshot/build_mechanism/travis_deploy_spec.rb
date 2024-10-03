# coding: utf-8
module Moonshot # rubocop:disable Metrics/ModuleLength
  describe BuildMechanism::TravisDeploy do
    let(:resources) do
      Resources.new(
        ilog: double(InteractiveLogger).as_null_object,
        stack: double(Stack).as_null_object,
        controller: instance_double(Moonshot::Controller).as_null_object
      )
    end
    let(:slug) { 'myorg/myrepo' }

    subject do
      s = described_class.new(slug)
      s.resources = resources
      s
    end

    describe '#doctor_hook' do
      it 'should call our hooks' do
        allow(subject).to receive(:puts)
        expect(subject).to receive(:puts).with('we did it')
        expect(subject).to receive(:print).with('  ✓ '.green)
        expect(subject).to receive(:doctor_check_travis_auth) do
          subject.send(:success, 'we did it')
        end
        subject.doctor_hook
      end

      describe '#doctor_check_travis_auth' do
        it 'should pass if travis exits 0' do
          expect(subject).to receive(:sh_out)
            .with('bundle exec travis raw --org repos/myorg/myrepo')
          expect(subject).to receive(:success)
            .with('`travis` installed and authorized.')
          subject.send(:doctor_check_travis_auth)
        end

        it 'should pass fail travis exits 1' do
          expect(subject).to receive(:sh_out)
            .with('bundle exec travis raw --org repos/myorg/myrepo')
            .and_raise(RuntimeError, 'stuffs broke man')
          expect(subject).to receive(:critical)
            .with("`travis` not available or not authorized.\nstuffs broke man")
          subject.send(:doctor_check_travis_auth)
        end
      end
    end

    describe '#wait_for_build' do
      let(:tag) { '0.0.0-rspec' }
      let(:job_number) { '1401.3' }
      let(:output) do
        "Build #1401:  Merge pull request #245 from respectest/updChange\n" \
        "State:         passed\nType:          push\n" \
        "Branch:        0.0.0-rspec\n" \
        "Compare URL:   https://github.com/acquia/moonshot/compare/0.0.0-rspec\n" \
        "Duration:      5 min 50 sec\nStarted:       2016-06-30 16:05:34\n" \
        "Finished:      2016-06-30 16:06:48\n\n" \
        "#1401.1 passed:  1 min 13 sec   rvm: 2.1.7, os: linux\n" \
        "#1401.2 passed:  1 min 14 sec   rvm: 2.2.3, os: linux\n" \
        '#1401.3 passed:  3 min 23 sec   rvm: 2.2.3, env: BUILD=1, ' \
        'gemfile: .travis.build.Gemfile, os: linux '
      end

      before(:each) do
        Retriable.configure do |c|
          c.sleep_disabled = true
        end
      end

      it 'should return the right job number' do
        expect(subject).to receive(:sh_out).and_return(output).once

        expect(subject.send(:wait_for_build, tag)).to eq(job_number)
      end

      it 'should only make the max number of attempts before failing' do
        expect(subject).to receive(:sh_out).and_raise.exactly(10).times

        expect { subject.send(:wait_for_build, tag) }.to \
          raise_error(RuntimeError)
      end

      it 'should make attempts until the build is found' do
        expect(subject).to receive(:sh_out).and_raise.twice
        expect(subject).to receive(:sh_out).and_return(output)

        expect(subject.send(:wait_for_build, tag)).to eq(job_number)
      end
    end

    describe '#wait_for_job' do
      let(:job_number) { '1401.3' }
      let(:repo) do
        instance_double(Travis::Client::Repository)
      end
      let(:step) do
        instance_double(InteractiveLogger::Step)
      end
      let(:job) do
        instance_double(
          Travis::Client::Job,
          state: 'received',
          finished?: false,
          reload: nil
        )
      end

      before(:each) do
        allow(subject).to receive(:authenticate)
        allow(subject).to receive(:repo).and_return(repo)
        allow(repo).to receive(:job).with(job_number).and_return(job)
      end

      it 'should continue until the job is complete' do
        expect(job).to receive(:state).and_return('started').exactly(3).times
        expect(job).to receive(:finished?).and_return(false).exactly(3).times
        expect(job).to receive(:finished?).and_return(true).twice
        expect(subject).to receive(:sleep).with(10).exactly(3).times

        expect(resources.ilog).to receive(:start_threaded).and_yield(step)
        expect(step).to receive(:continue).with('Job status: started')
          .exactly(3).times
        expect(step).to receive(:success)

        subject.send(:wait_for_job, job_number)
      end

      it 'should fail if the job does not complete within the time limit' do
        expect(resources.ilog).to receive(:start_threaded).and_yield(step)
        expect(step).to receive(:continue).at_least(9)
        expect(step).to receive(:failure)
        expect(subject).to receive(:sleep).at_least(:once) { sleep 0.1 }

        subject.instance_variable_set(:@timeout, 1)
        subject.send(:wait_for_job, job_number)
      end
    end
  end
end
