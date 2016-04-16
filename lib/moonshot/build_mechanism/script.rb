require 'open3'
include Open3

# Compile a release artifact using a shell script.
#
# The output file will be deleted before the script is run, and is expected to
# exist after the script exits. Any non-zero exit status will be consider a
# build failure, and any output will be displayed to the user.
#
# Creating a new Script BuildMechanism looks like this:
#
# class MyReleaseTool < Moonshot::CLI
#   include Moonshot::BuildMechanism
#   self.build_mechanism = Script.new('script/build.sh')
# end
#
class Moonshot::BuildMechanism::Script
  include Moonshot::ResourcesHelper
  include Moonshot::DoctorHelper

  attr_reader :output_file

  def initialize(script, output_file: 'output.tar.gz')
    @script = script
    @output_file = output_file
  end

  def pre_build_hook(_version)
    File.delete(@output_file) if File.exist?(@output_file)
  end

  def build_hook(version)
    env = {
      'VERSION' => version,
      'OUTPUT_FILE' => @output_file
    }
    ilog.start_threaded "Running Script: #{@script}" do |s|
      run_script(s, env: env)
    end
  end

  def post_build_hook(_version)
    unless File.exist?(@output_file) # rubocop:disable GuardClause
      raise 'Build command did not produce output file!'
    end
  end

  private

  def run_script(step, env: {})
    popen2e(env, @script) do |_, out, wait|
      output = []

      loop do
        str = out.gets
        unless str.nil?
          output << str.chomp
          ilog.debug(str.chomp)
        end
        break if out.eof?
      end

      result = wait.value
      if result.exitstatus == 0
        step.success "Build script #{@script} exited successfully!"
      end
      unless result.exitstatus == 0
        ilog.error "Build script failed with exit status #{result.exitstatus}!"
        ilog.error output.join("\n")
        step.failure "Build script #{@script} failed with exit status #{result.exitstatus}!"
      end
    end
  end

  def doctor_check_script_exists
    if File.exist?(@script)
      success "Script '#{@script}' exists."
    else
      critical "Could not find build script '#{@script}'!"
    end
  end
end
