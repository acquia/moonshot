require 'thor'

# Mixin providing the Thor::Shell methods and other shell execution helpers.
module Moonshot::Shell
  # Run a command, returning stdout. Stderr is suppressed unless the command
  # returns non-zero.
  def sh_out(cmd, fail: true, stdin: '')
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
      raise "`#{cmd}` exited #{$CHILD_STATUS.exitstatus}\n" \
           "stdout:\n" \
           "#{stdout}\n" \
           "stderr:\n" \
           "#{stderr}\n"
    end
    stdout
  end
  module_function :sh_out

  def shell
    @thor_shell ||= Thor::Base.shell.new
  end

  Thor::Shell::Basic.public_instance_methods(false).each do |meth|
    define_method(meth) { |*args| shell.public_send(meth, *args) }
  end

  def sh_step(cmd, args = {})
    msg = args.delete(:msg) || cmd
    if msg.length > (terminal_width - 18)
      msg = "#{msg[0..(terminal_width - 22)]}..."
    end
    ilog.start_threaded(msg) do |step|
      out = sh_out(cmd, args)
      yield step, out if block_given?
      step.success
    end
  end
end
