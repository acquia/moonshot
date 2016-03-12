require 'bundler/setup'
require 'cucumber/rake/task'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

Cucumber::Rake::Task.new(:features)

desc 'Run RuboCop against the source code.'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.options << '--display-cop-names'
  task.options << '--display-style-guide'
end

RSpec::Core::RakeTask.new(:spec)

task default: [:spec, :rubocop]
