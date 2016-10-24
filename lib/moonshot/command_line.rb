require 'thor'

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

    def run! # rubocop:disable AbcSize, CyclomaticComplexity, MethodLength, PerceivedComplexity
      return if handle_early_commands

      # Find the Moonfile in this project.
      orig_dir = Dir.pwd

      loop do
        break if File.exist?('Moonfile.rb')

        if Dir.pwd == '/'
          raise 'No Moonfile.rb found, are you in a project? Maybe you need to '\
	        			'create one with `moonshot new <app_name>`?'
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
      if %w(--help -h help).include?(command) || command.nil?
        usage
        return
      end

      # Dispatch to that command, by executing it's parser, then
      # comparing ARGV to the execute methods arity.
      unless @commands.key?(command)
        usage
        raise "Command not found '#{command}'"
      end

      handler = @commands[command].new
      handler.parser.parse!

      unless ARGV.size == handler.method(:execute).arity
        warn handler.parser.help
        raise "Invalid command line for '#{command}'."
      end

      handler.execute(*ARGV)
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
      fields = []
      @commands.each do |c, k|
        fields << [c, k.description]
      end

      max_len = fields.map(&:first).map(&:size).max

      fields.each do |f|
        line = format("  %-#{max_len}s # %s", *f)
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
    end

    def commandify(klass)
      word = klass.to_s.split('::').last
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2'.freeze)
      word.gsub!(/([a-z\d])([A-Z])/, '\1_\2'.freeze)
      word.tr!('_'.freeze, '-'.freeze)
      word.downcase!
      word
    end

<<<<<<< 0c51452e2a612c9758a410c433bab67fb2fdd456
    def handle_early_commands
      # If this is a legacy (Thor) help command, re-write it as
      # OptionParser format.
      if ARGV[0] == 'help'
        ARGV.delete_at(0)
        ARGV.push('-h')
      end

      # Proceed to processing commands normally.
      false
=======
    def self.handle_early_commands(args)
      command = args.first
      case command
      when 'new'
        require_relative 'commands/new'
        app_name = args[1]
        ::Moonshot::Commands::New.run!(app_name)
      when '--help'
        warn 'Usage: moonshot new <app_name>'
      else
        throw(:regular_command)
      end
>>>>>>> Introduced 'new' command.
    end
  end
end
