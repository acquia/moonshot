# frozen_string_literal: true

require 'open3'

module Moonshot
  # Run an SSH command via fork/exec.
  class SSHForkExecutor
    Result = Struct.new(:output, :error, :exitstatus)

    def run(cmd)
      output = error = StringIO.new
      exit_status = nil
      Open3.popen3(cmd) do |_, stdout, stderr, wt|
        error << stderr.read until stderr.eof?
        output << stdout.read until stdout.eof?
        exit_status = wt.value.exitstatus
      end

      Result.new(output.string.chomp, error.string.chomp, exit_status)
    end
  end
end
