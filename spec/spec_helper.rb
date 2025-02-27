if ENV['COVERAGE']
  require 'simplecov'

  SimpleCov.start do
    add_filter '/spec/'
  end
end

# RSpec brings this in ad-hoc, but if it comes in after fakefs we get
# superclass mismatch errors.
require 'pp'
require 'moonshot'
require 'fakefs/spec_helpers'

puts "rspec pid: #{Process.pid}"
trap 'USR1' do
  threads = Thread.list

  puts
  puts '=' * 80
  puts "Received USR1 signal; printing all #{threads.count} thread backtraces."

  threads.each do |thr|
    description = thr == Thread.main ? 'Main thread' : thr.inspect
    puts
    puts "#{description} backtrace: "
    puts thr.backtrace.join("\n")
  end

  puts '=' * 80
end

class MockInteractiveLogger
  attr_reader :final_logs

  def initialize
    @final_logs = []
  end

  def start(msg = nil)
    @msg = msg
    yield self
  end
  alias start_threaded start

  def continue(msg = nil)
    @msg = msg if msg
  end

  def success(msg = nil)
    @final_logs << [:success, msg || @msg]
  end

  def failure(msg = nil)
    @final_logs << [:failure, msg || @msg]
  end

  def debug(msg)
    @final_logs << [:debug, msg]
  end

  def info(msg)
    @final_logs << [:info, msg]
  end
end

shared_examples 'with a working moonshot application' do
  include FakeFS::SpecHelpers

  before(:all) do
    # Force aws-sdk to load metadata before FakeFS takes over.
    begin
      Aws::CloudFormation::Client.new
    rescue
    end
  end

  before(:each) do
    FakeFS::FileSystem.clone(File.join(File.dirname(__FILE__), 'fs_fixtures'), '/')
  end
end

shared_examples 'with a CloudFormation stubbed client' do
  let(:cf_client_stubs) { {} }
  let(:cf_client) { Aws::CloudFormation::Client.new(stub_responses: cf_client_stubs) }

  before(:each) do
    allow(Aws::CloudFormation::Client).to receive(:new).and_return(cf_client)
  end
end

def fixture_path(path)
  File.join(File.dirname(__FILE__), 'fixtures', path)
end

def fixture(path)
  File.read(fixture_path(path))
end
