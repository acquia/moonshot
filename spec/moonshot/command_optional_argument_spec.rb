class OptionalArgumentCommand < Moonshot::Command
  def execute(version = 'development')
    puts "selected version: #{version}"
  end
end

describe 'optional argument for command' do
  def try(klass, args = [])
    Moonshot::CommandLineDispatcher.new('stuff', klass, args)
      .dispatch!
  end

  Moonshot::AccountContext.set('optional-account')
  ARGV.clear

  it 'should let us run OptionalArgumentCommand without extra arguments' do
    expect { try(OptionalArgumentCommand) }
      .to output(/selected version: development/).to_stdout
  end

  it 'should let us run OptionalArgumentCommand with extra argument' do
    expect { try(OptionalArgumentCommand, ['production']) }
      .to output(/selected version: production/).to_stdout
  end
end
