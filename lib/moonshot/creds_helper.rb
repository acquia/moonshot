module Moonshot
  # Create convenience methods for various AWS client creation.
  module CredsHelper
    def cf_client
      Aws::CloudFormation::Client.new
    end

    def cd_client
      Aws::CodeDeploy::Client.new
    end

    def ec2_client
      Aws::EC2::Client.new
    end

    def iam_client
      Aws::IAM::Client.new
    end

    def as_client
      Aws::AutoScaling::Client.new
    end

    def s3_client
      Aws::S3::Client.new
    end

    def elb_client
      Aws::ElasticLoadBalancing::Client.new
    end
  end
end
