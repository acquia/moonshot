module Moonshot
  class CommandLineDispatcher
    def initialize(command, klass, args)
      @command = command
      @klass = klass
      @args = args
    end

    def dispatch!
      # Look to see if we're allowed only to run in certain accounts, or
      # not allowed to run in specific accounts.
      check_account_restrictions

      # Allow any mechanisms or plugins to hook into this CLI command.
      handler = @klass.new
      parser = build_parser(handler)
      parser.parse!

      req_arguments = handler.method(:execute).parameters.select { |arg| arg[0] == :req }
      if ARGV.size < req_arguments.size
        warn handler.parser.help
        raise "Invalid command line for '#{@command}'."
      end

      handler.execute(*@args)
    end

    private

    def check_account_restrictions
      this_account = Moonshot::AccountContext.get

      return if @klass.only_in_account.nil? ||
                Array(@klass.only_in_account).any? { |a| a == this_account }

      warn "'#{@command}' can only be run in the following accounts:"
      Array(@klass.only_in_account).each do |account_name|
        warn "- #{account_name}"
      end

      raise 'Command account restriction violation.'
    end

    def build_parser(handler)
      parser = handler.parser

      # Each mechanism / plugin may manipulate the OptionParser object
      # associated with this command.
      [:build_mechanism, :deployment_mechanism, :artifact_repository].each do |prov|
        provider = Moonshot.config.send(prov)

        if provider.respond_to?(hook_func_name(@command))
          parser = provider.send(hook_func_name(@command), parser)
        end
      end

      Moonshot.config.plugins.each do |plugin|
        if plugin.respond_to?(hook_func_name(@command))
          parser = plugin.send(hook_func_name(@command), parser)
        end
      end

      parser
    end

    # Name of the function a plugin or mechanism could define to manipulate
    # the parser for a command.
    def hook_func_name(command)
      command.tr('-', '_') << '_cli_hook'
    end
  end
end
