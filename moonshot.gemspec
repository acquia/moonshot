# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'moonshot'
  s.version     = '3.0.4'
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

  s.required_ruby_version = '>= 3.3.4'

  s.add_dependency('aws-sdk-autoscaling', '~> 1.5')
  s.add_dependency('aws-sdk-cloudformation', '~> 1.4')
  s.add_dependency('aws-sdk-codedeploy', '~> 1.5')
  s.add_dependency('aws-sdk-ec2', '~> 1.34')
  s.add_dependency('aws-sdk-elasticloadbalancing', '~> 1.3')
  s.add_dependency('aws-sdk-iam', '~> 1.4')
  s.add_dependency('aws-sdk-s3', '~> 1.12')

  s.add_dependency('activesupport')
  s.add_dependency('colorize')
  s.add_dependency('commonmarker','~> 0.23.10')
  s.add_dependency('faraday', '~> 1.0')
  s.add_dependency('faraday-rack', '~> 1.0.0')
  s.add_dependency('faraday-retry', '~> 1.0')
  s.add_dependency('highline')
  s.add_dependency('interactive-logger')
  s.add_dependency('pry')
  s.add_dependency('require_all')
  s.add_dependency('retriable')
  s.add_dependency('rexml')
  s.add_dependency('rotp')
  s.add_dependency('ruby-duration')
  s.add_dependency('semantic')
  s.add_dependency('thor')
  s.add_dependency('vandamme', '1.4.0')

  s.add_development_dependency('fakefs')
  s.add_development_dependency('rspec')
  s.add_development_dependency('simplecov')
end
