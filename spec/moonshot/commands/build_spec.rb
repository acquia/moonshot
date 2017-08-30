describe Moonshot::Commands::Build do

  it 'should not handle --skip-ci-status and build correctly' do
    cli_dispatcher = Moonshot::CommandLineDispatcher.new('build', subject, {})
    parser = cli_dispatcher.send(:build_parser, subject)
    expect { parser.parse(%w(--skip-ci-status)) }.to raise_error(RuntimeError)
  end
  
  it 'should handle --skip-ci-status and build correctly' do
    Moonshot.config = Moonshot::ControllerConfig.new
    Moonshot.config do |c|
      c.build_mechanism = Moonshot::BuildMechanism::GithubRelease.new('')
    end
    cli_dispatcher = Moonshot::CommandLineDispatcher.new('build', subject, {})
    parser = cli_dispatcher.send(:build_parser, subject)
    expect { parser.parse(%w(--skip-ci-status)) }.to_not raise_error
  end 
  
end
