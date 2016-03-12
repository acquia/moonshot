Given(/^I use the moonshot fixture "([^"]*)"$/) do |fixture_name|
  step("I use a fixture named \"#{fixture_name}\"")
  unset_bundler_env_vars
  Bundler.with_clean_env do
    run_simple("bash -l -c 'bundle install --binstubs=binstubs'")
  end
  expect('binstubs').to be_an_existing_directory
  prepend_environment_variable('PATH', "#{expand_path('.')}/binstubs:")
end

# I would word this as I set... if not set, but aruba steps are too broad.
Given(/^I default the environment variable "([^"]*)" to "([^"]*)"$/) do |variable, value| # rubocop:disable Metrics/LineLength
  next if aruba.environment[variable]
  set_environment_variable(variable.to_s, value.to_s)
end
