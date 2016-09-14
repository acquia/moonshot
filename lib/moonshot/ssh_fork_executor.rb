require 'open3'

module Moonshot
  # Run an SSH command via fork/exec.
  class SSHForkExecutor
    Result = Struct.new(:output, :exitstatus)

    def run(cmd)
      output = StringIO.new

      exit_status = nil
      Open3.popen3(cmd) do |_, stdout, _, wt|
        output << stdout.read until stdout.eof?
        exit_status = wt.value.exitstatus
      end

      Result.new(output.string.chomp, exit_status)
    end
  end
end
