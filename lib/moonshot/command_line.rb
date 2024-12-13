# frozen_string_literal: true

module Moonshot
  # This class implements the command-line `moonshot` tool.
  class CommandLine
    def self.register(klass)
      @classes ||= []
      @classes << klass
    end

    def self.registered_commands
      @classes || []
    end

    def run! # rubocop:disable Metrics/MethodLength
      # Commands defined as Moonshot::Commands require a properly
      # configured Moonshot.rb and supporting files. Without them, we only
      # support `--help` and `new`.
      return if handle_early_commands

      # Find the Moonfile in this project.
      orig_dir = Dir.pwd

      loop do
        break if File.exist?('Moonfile.rb')

        if Dir.pwd == '/'
          warn 'No Moonfile.rb found, are you in a project? Maybe you need to ' \
               'create one with `moonshot new <app_name>`?'
          raise 'No Moonfile found'
        end

        Dir.chdir('..')
      end

      moonfile_dir = Dir.pwd
      Dir.chdir(orig_dir)

      # Load any plugins and CLI extensions relative to the Moonfile
      if File.directory?(File.join(moonfile_dir, 'moonshot'))
        load_plugins(moonfile_dir)
        load_cli_extensions(moonfile_dir)
      end

      Object.include(Moonshot::ArtifactRepository)
      Object.include(Moonshot::BuildMechanism)
      Object.include(Moonshot::DeploymentMechanism)
      load(File.join(moonfile_dir, 'Moonfile.rb'))

      Moonshot.config.project_root = moonfile_dir

      load_commands

      # Determine what command is being run, which should be the first argument.
      command = ARGV.shift
      if %w[--help -h help].include?(command) || command.nil?
        usage
        return
      end

      # Dispatch to that command, by executing it's parser, then
      # comparing ARGV to the execute methods arity.
      unless @commands.key?(command)
        usage
        raise "Command not found '#{command}'"
      end

      command_class = @commands[command]

      CommandLineDispatcher.new(command, command_class, ARGV).dispatch!
    end

    def load_plugins(moonfile_dir)
      plugins_path = File.join(moonfile_dir, 'moonshot', 'plugins', '**', '*.rb')
      Dir.glob(plugins_path).each do |file|
        load(file)
      end
    end

    def load_cli_extensions(moonfile_dir)
      cli_extensions_path = File.join(moonfile_dir, 'moonshot', 'cli_extensions', '**', '*.rb')
      Dir.glob(cli_extensions_path).each do |file|
        load(file)
      end
    end

    def usage
      warn 'Usage: moonshot [command]'
      warn
      warn 'Valid commands include:'
      fields = @commands.map do |c, k|
        [c, k.description]
      end

      max_len = fields.map(&:first).map(&:size).max

      fields.each do |f|
        line = format("  %-#{max_len}s # %s", *f) # rubocop:disable Lint/FormatParameterMismatch
        warn line
      end
    end

    def load_commands
      @commands = {}

      # Include all Moonshot::Command and Moonshot::SSHCommand
      # derived classes as subcommands, with the description of their
      # default task.
      self.class.registered_commands.each do |klass|
        next unless klass.instance_methods.include?(:execute)

        command_name = commandify(klass)
        @commands[command_name] = klass
      end

      @commands = @commands.sort_by { |k, _v| k.to_s }.to_h
    end

    def commandify(klass)
      word = klass.to_s.split('::').last
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
      word.tr!('_', '-')
      word.downcase!
      word
    end

    def handle_early_commands
      # If this is a legacy (Thor) help command, re-write it as
      # OptionParser format.
      case ARGV[0]
      when 'help'
        ARGV.delete_at(0)
        ARGV.push('-h')
      when 'new'
        app_name = ARGV[1]
        ::Moonshot::Commands::New.run!(app_name)
        return true
      end

      # Proceed to processing commands normally.
      false
    end
  end
end
