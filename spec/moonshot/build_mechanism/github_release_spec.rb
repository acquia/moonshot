module Moonshot # rubocop:disable ModuleLength
  describe BuildMechanism::GithubRelease do
    let(:tag) { '0.0.0-rspec' }
    let(:build_mechanism) do
      instance_double(BuildMechanism::Script).as_null_object
    end

    let(:resources) do
      Resources.new(
        ilog: instance_double(InteractiveLogger).as_null_object,
        stack: instance_double(Stack).as_null_object,
        controller: instance_double(Moonshot::Controller).as_null_object
      )
    end

    let(:slug) { 'myorg/myrepo' }

    subject do
      s = described_class.new(build_mechanism)
      s.resources = resources
      s
    end

    describe '#doctor_hook' do
      it 'should call our hooks' do
        allow(subject).to receive(:puts)
        allow(subject).to receive(:print)
        expect(subject).to receive(:doctor_check_hub_auth)
        expect(subject).to receive(:doctor_check_upstream)
        subject.doctor_hook
      end

      describe '#doctor_check_upstream' do
        around do |example|
          Dir.mktmpdir do |path|
            Dir.chdir(path) do
              `git init`
              example.run
            end
          end
        end

        it 'should fail without upstream.' do
          expect(subject).to receive(:critical)
            .with(/git remote `upstream` not found/)
          subject.send(:doctor_check_upstream)
        end

        it 'should succeed with upstream remote.' do
          `git remote add upstream https://example.com/my/repo.git`
          expect(subject).to receive(:success)
            .with('git remote `upstream` exists.')
          subject.send(:doctor_check_upstream)
        end
      end

      describe '#doctor_check_hub_auth' do
        it 'should succeed with 0 exit status.' do
          expect(subject).to receive(:sh_out)
            .with('hub ci-status 0.0.0')
          expect(subject).to receive(:success)
            .with('`hub` installed and authorized.')
          subject.send(:doctor_check_hub_auth)
        end

        it 'should critical with non-zero exit status.' do
          expect(subject).to receive(:sh_out)
            .with('hub ci-status 0.0.0')
            .and_raise(RuntimeError, 'oops')
          expect(subject).to receive(:critical)
            .with("`hub` failed, install hub and authorize it.\noops")
          subject.send(:doctor_check_hub_auth)
        end
      end
    end

    describe '#git_tag_exists' do
      let(:sha) { '1397919abb5b7c0908ab42eaac501d68a0ccb6db' }

      it 'passes if the tag exists at the same sha' do
        expect(subject).to receive(:sh_step).with("git tag -l #{tag}")
          .and_yield(nil, tag)
        expect(subject).to receive(:sh_step).with("git rev-list -n 1 #{tag}")
          .and_yield(nil, sha)

        expect(subject.send(:git_tag_exists, tag, sha)).to eq(true)
      end

      it 'fails if the tag does not exist' do
        expect(subject).to receive(:sh_step).with("git tag -l #{tag}")
          .and_yield(nil, '')
        expect(subject).to_not receive(:sh_step)
          .with("git rev-list -n 1 #{tag}")

        expect(subject.send(:git_tag_exists, tag, sha)).to eq(false)
      end

      it 'errors if the tag exists at a different sha' do
        expect(subject).to receive(:sh_step).with("git tag -l #{tag}")
          .and_yield(nil, tag)
        expect(subject).to receive(:sh_step).with("git rev-list -n 1 #{tag}")
          .and_yield(nil, '72774c1855c044e917f322e9536a4e3f62697267')

        expect { subject.send(:git_tag_exists, tag, sha) }.to \
          raise_error(RuntimeError)
      end
    end

    describe '#hub_release_exists' do
      it 'passes if the github release exists' do
        expect(subject).to receive(:sh_step).with("hub release show #{tag}")

        expect(subject.send(:hub_release_exists, tag)).to eq(true)
      end

      it 'fails if the github release does not exist' do
        expect(subject).to receive(:sh_step).with("hub release show #{tag}")
          .and_raise

        expect(subject.send(:hub_release_exists, tag)).to eq(false)
      end
    end
  end
end
