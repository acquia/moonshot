# frozen_string_literal: true

require 'thor'
require 'retriable'

# Mixin providing the Thor::Shell methods and other shell execution helpers.
module Moonshot::Shell
  CommandError = Class.new(RuntimeError)

  # Retry every 10 seconds for a maximum of 2 minutes.
  DEFAULT_RETRY_OPTIONS = {
    on: RuntimeError,
    tries: 50,
    multiplier: 1,
    base_interval: 10,
    max_elapsed_time: 120,
    rand_factor: 0
  }.freeze

  # Run a command, returning stdout. Stderr is suppressed unless the command
  # returns non-zero.
  def sh_out(cmd, fail = true, stdin = '') # rubocop:disable Style/OptionalBooleanParameter
    r_in, w_in = IO.pipe
    r_out, w_out = IO.pipe
    r_err, w_err = IO.pipe
    w_in.write(stdin)
    w_in.close
    pid = Process.spawn(cmd, in: r_in, out: w_out, err: w_err)
    Process.wait(pid)

    r_in.close
    w_out.close
    w_err.close
    stdout = r_out.read
    r_out.close
    stderr = r_err.read
    r_err.close

    if fail && $CHILD_STATUS.exitstatus != 0
      raise CommandError, "`#{cmd}` exited #{$CHILD_STATUS.exitstatus}\n" \
           "stdout:\n" \
           "#{stdout}\n" \
           "stderr:\n" \
           "#{stderr}\n"
    end
    stdout
  end
  module_function :sh_out

  def shell
    @shell ||= Thor::Base.shell.new
  end

  Thor::Shell::Basic.public_instance_methods(false).each do |meth|
    define_method(meth) { |*args| shell.public_send(meth, *args) }
  end

  def sh_step(cmd, **args)
    msg = args.delete(:msg) || cmd
    msg = "#{msg[0..(terminal_width - 22)]}..." if msg.length > (terminal_width - 18)
    ilog.start_threaded(msg) do |step|
      out = sh_out(cmd, **args)
      yield step, out if block_given?
      step.success
    end
  end

  # Retries every second upto maximum of 2 minutes with the default options.
  #
  # @param cmd [String] command to execute.
  # @param fail [Boolean] Raise error when the command exits with non-zero.
  # @param stdin [String] Input to the command.
  # @param opts [Hash] Options for retriable.
  #
  # @return [String] Stdout form the command.
  def sh_retry(cmd, fail = true, stdin = '', opts: {}) # rubocop:disable Style/OptionalBooleanParameter
    Retriable.retriable(DEFAULT_RETRY_OPTIONS.merge(opts)) do
      out = sh_out(cmd, stdin:)
      yield out if block_given?
      out
    end
  rescue CommandError => e
    raise e if fail
  end
end
