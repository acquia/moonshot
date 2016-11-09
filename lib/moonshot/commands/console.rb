require 'pry'

module Moonshot
  module Commands
    class Console < Moonshot::Command
      self.usage = 'console [options]'
      self.description = 'Launch a interactive Ruby console with configured access to AWS'

      def execute
        controller

        ec2 = Aws::EC2::Client.new
        iam = Aws::IAM::Client.new
        autoscaling = Aws::AutoScaling::Client.new
        cf = Aws::CloudFormation::Client.new

        Pry.start binding, backtrace: nil
      end
    end
  end
end
