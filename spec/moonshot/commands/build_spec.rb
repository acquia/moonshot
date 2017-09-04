describe Moonshot::Commands::Build do

  it 'should raise RuntimeError when send --skip-ci-status param without GithubRelease plugin' do
    cli_dispatcher = Moonshot::CommandLineDispatcher.new('build', subject, {})
    parser = cli_dispatcher.send(:build_parser, subject)
    expect { parser.parse(%w(--skip-ci-status)) }.to raise_error(RuntimeError)
  end
  
  it 'should not raise RuntimeError when send --skip-ci-status param with GithubRelease plugin' do
    Moonshot.config = Moonshot::ControllerConfig.new
    Moonshot.config do |c|
      c.build_mechanism = Moonshot::BuildMechanism::GithubRelease.new('')
    end
    cli_dispatcher = Moonshot::CommandLineDispatcher.new('build', subject, {})
    parser = cli_dispatcher.send(:build_parser, subject)
    expect { parser.parse(%w(--skip-ci-status)) }.to_not raise_error
  end 
  
end
