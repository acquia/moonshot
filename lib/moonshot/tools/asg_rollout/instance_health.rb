module Moonshot
  module Tools
    class ASGRollout
      class InstanceHealth
        attr_reader :asg_status, :elb_status

        VALID_ASG_IN_SERVICE_STATES = ['InService'].freeze
        VALID_ELB_IN_SERVICE_STATES = [nil, 'InService'].freeze

        VALID_ASG_OUT_OF_SERVICE_STATES = [nil, 'Missing', 'Detached'].freeze
        VALID_ELB_OUT_OF_SERVICE_STATES = [nil, 'Missing', 'OutOfService'].freeze

        def initialize(asg_status, elb_status)
          @asg_status = asg_status
          @elb_status = elb_status
        end

        def to_s
          result = "ASG:#{@asg_status}"
          result << "/ELB:#{@elb_status}" if @elb_status
          result
        end

        def in_service?
          VALID_ASG_IN_SERVICE_STATES.include?(@asg_status) &&
            VALID_ELB_IN_SERVICE_STATES.include?(@elb_status)
        end

        def out_of_service?
          VALID_ASG_OUT_OF_SERVICE_STATES.include?(@asg_status) &&
            VALID_ELB_OUT_OF_SERVICE_STATES.include?(@elb_status)
        end
      end
    end
  end
end
