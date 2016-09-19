require 'aruba/cucumber'

Aruba.configure do |config|
  config.exit_timeout                          = 120
  config.activate_announcer_on_command_failure = [:stderr, :stdout, :command]
end
