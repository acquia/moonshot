# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'moonshot'
  s.version     = '3.0.0'
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

  s.add_dependency('aws-sdk', '~> 2.0', '>= 2.2.0')

  s.required_ruby_version = '>= 3.1.2'

  s.add_dependency('activesupport')
  s.add_dependency('colorize')
  s.add_dependency('highline')
  s.add_dependency('interactive-logger')
  s.add_dependency('pry')
  s.add_dependency('require_all')
  s.add_dependency('retriable')
  s.add_dependency('rotp')
  s.add_dependency('ruby-duration')
  s.add_dependency('semantic')
  s.add_dependency('thor')
  s.add_dependency('travis')
  s.add_dependency('vandamme')

  s.add_development_dependency('fakefs')
  s.add_development_dependency('rspec')
  s.add_development_dependency('simplecov')
end
