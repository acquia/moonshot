require 'forwardable'

module Moonshot
  # This class pretends to be an InteractiveLogger for systems that are
  # non-interactive.
  class InteractiveLoggerProxy
    # Non-interactive version of InteractiveLogger::Step.
    class Step
      def initialize(logger)
        @logger = logger
      end

      def blank; end

      def continue(str = nil)
        @logger.info(str) if str
      end

      def failure(str = 'Failure')
        @logger.error(str)
      end

      def repaint; end

      def success(str = 'Success')
        @logger.info(str)
      end
    end

    extend Forwardable

    def_delegator :@debug, :itself, :debug?
    def_delegators :@logger, :debug, :error, :info
    alias msg info

    def initialize(logger, debug: false)
      @debug = debug
      @logger = logger
    end

    def start(str)
      @logger.info(str)
      yield Step.new(@logger)
    end
    alias start_threaded start
  end
end
