module Moonshot
  module Tools
    class ASGRollout
      # Provides an abstraction around an Auto Scaling Group's
      # relationship with an instance.
      class ASGInstance
        attr_reader :asg_name, :id

        def initialize(asg_name, id, _config)
          @asg_name = asg_name
          @instance_id = id
        end
      end
    end
  end
end
