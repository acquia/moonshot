# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rake', require: false

gem 'interactive-logger',
    git: 'https://github.com/imnetworku/interactive-logger.git',
    branch: 'ruby-3.3.6'

group :test do
  gem 'codeclimate-test-reporter'
  gem 'pry'
  gem 'rubocop'
end

group :development do
  gem 'fakefs'
  gem 'rspec'
  gem 'simplecov'
end
