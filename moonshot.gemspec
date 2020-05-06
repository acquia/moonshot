Gem::Specification.new do |s|
  s.name        = 'moonshot'
  s.version     = '2.1.0.beta1'
  s.licenses    = ['Apache-2.0']
  s.summary     = 'A library and CLI tool for launching services into AWS'
  s.description = 'A library and CLI tool for launching services into AWS.'
  s.authors     = [
    'Cloud Engineering <engineering@acquia.com>'
  ]
  s.email       = 'engineering@acquia.com'
  s.files       = Dir['lib/**/*.rb'] + Dir['lib/default/**/*'] + Dir['bin/*']
  s.bindir      = 'bin'
  s.executables = ['moonshot']
  s.homepage    = 'https://github.com/acquia/moonshot'

  s.add_dependency('aws-sdk-cloudformation', '~> 1.4')
  s.add_dependency('aws-sdk-codedeploy', '~> 1.5')
  s.add_dependency('aws-sdk-ec2', '~> 1.34')
  s.add_dependency('aws-sdk-iam', '~> 1.4')
  s.add_dependency('aws-sdk-autoscaling', '~> 1.5')
  s.add_dependency('aws-sdk-s3', '~> 1.12')

  s.add_dependency('colorize')
  s.add_dependency('highline', '~> 1.7.2')
  s.add_dependency('interactive-logger', '~> 0.1.2')
  s.add_dependency('rotp', '~> 2.1.1')
  s.add_dependency('ruby-duration', '~> 3.2.3')
  s.add_dependency('retriable')
  # Pin back activesupport (ruby-duration dependency) until we only support
  # Ruby >= 2.2.2.
  s.add_dependency('activesupport', '< 5.0.0')
  s.add_dependency('thor', '~> 0.19.1')
  s.add_dependency('semantic')
  s.add_dependency('travis')
  s.add_dependency('vandamme')
  s.add_dependency('pry')
  s.add_dependency('require_all', '~> 1.5.0')

  s.add_development_dependency('rspec')
  # Workaround for cc-test-reporter with SimpleCov 0.18.
  # Stop upgrading SimpleCov until the following issue will be resolved.
  # https://github.com/codeclimate/test-reporter/issues/418
  s.add_development_dependency('simplecov', '~> 0.17.1')
  # fakefs requires < 0.14.0 for ruby 2.2
  s.add_development_dependency('fakefs', '< 0.14.0')
end
