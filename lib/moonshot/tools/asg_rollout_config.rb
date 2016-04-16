module Moonshot
  module Tools
    class ASGRolloutConfig
      attr_reader :pre_detach, :terminate_when, :terminate_when_timeout, :terminate
      attr_accessor :terminate_when_delay, :instance_health_delay

      def initialize
        @instance_health_delay = 2
        @terminate_when_delay = 1
        @terminate_when_timeout = 300
        @terminate = proc do |h|
          h.ec2_instance.terminate
        end
      end

      def pre_detach=(value)
        raise ArgumentError, 'pre_detach must be callable' unless value.respond_to?(:call)

        @pre_detach = value
      end

      def terminate_when=(value)
        raise ArgumentError, 'terminate_when must be callable' unless value.respond_to?(:call)

        @terminate_when = value
      end

      def terminate_when_timeout=(value)
        @terminate_when_timeout = Float(value)
      end

      def terminate=(value)
        raise ArgumentError, 'terminate must be callable' unless value.respond_to?(:call)

        @terminate = value
      end
    end
  end
end
