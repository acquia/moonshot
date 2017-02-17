require 'optparse'

module Moonshot
  # A Command that is automatically registered with the Moonshot::CommandLine
  class Command
    module ClassMethods
      # TODO: Can we auto-generate usage for commands with no positional arguments, at least?
      attr_accessor :usage, :description, :only_in_account
    end

    def self.inherited(base)
      Moonshot::CommandLine.register(base)
      base.extend(ClassMethods)
    end

    def parser
      @use_interactive_logger = true

      OptionParser.new do |o|
        o.banner = "Usage: moonshot #{self.class.usage}"

        o.on('-v', '--[no-]verbose', 'Show debug logging') do |v|
          Moonshot.config.interactive_logger = InteractiveLogger.new(debug: true) if v
        end

        o.on('-nNAME', '--environment=NAME', 'Which environment to operate on.') do |v|
          Moonshot.config.environment_name = v
        end

        o.on('--[no-]interactive-logger', TrueClass, 'Enable or disable fancy logging') do |v|
          @use_interactive_logger = v
        end
      end
    end

    private

    # Build a Moonshot::Controller from the CLI options.
    def controller
      config = Moonshot.config
      config.update_for_account!
      controller = Moonshot::Controller.new(config)

      # Degrade to a more compatible logger if the terminal seems outdated,
      # or at the users request.
      if !$stdout.isatty || !@use_interactive_logger
        log = Logger.new(STDOUT)
        controller.config.interactive_logger = InteractiveLoggerProxy.new(log)
      end

      controller
    end
  end
end
