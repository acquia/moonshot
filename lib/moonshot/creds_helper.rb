module Moonshot
  # Create convenience methods for various AWS client creation.
  module CredsHelper
    def cf_client(**args)
      Aws::CloudFormation::Client.new(args)
    end

    def cd_client(**args)
      Aws::CodeDeploy::Client.new(args)
    end

    def ec2_client(**args)
      Aws::EC2::Client.new(args)
    end

    def iam_client(**args)
      Aws::IAM::Client.new(args)
    end

    def as_client(**args)
      Aws::AutoScaling::Client.new(args)
    end

    def s3_client(**args)
      Aws::S3::Client.new(args)
    end
  end
end
