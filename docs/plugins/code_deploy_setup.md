# Moonshot CodeDeploy Setup plugin
Moonshot plugin to ensure CodeDeploy has all the necessary S3 buckets created
 to support deploying to multiple configured regions.

## Moonshot configuration
Update your Moonfile.rb with the following configuration

```ruby
Moonshot.config do |c|
  # ...
  c.app_name = 'example-project'

  bucket_name = "#{c.app_name}-builds"

  # bucket_name: Base name of the S3 bucket to create, will have region appended to it.
  # prefix: Optional. If using the same bucket for multiple apps then recommend adding a prefix.
  # regions: list of all supported regions you would like to use. Default: ENV['AWS_REGION'].
  code_deploy_setup_plugin = Moonshot::Plugins::CodeDeploySetup.new(
    bucket_name,
    prefix: c.app_name,
    regions: [ 'us-east-1', 'us-west-2' ]
  c.plugins << code_deploy_setup_plugin

  c.deployment_mechanism = CodeDeploy.new
  c.artifact_repository = S3BucketViaGithubReleases.new(
    code_deploy_setup_plugin.bucket_name,
    prefix: code_deploy_setup_plugin.bucket_prefix
  )
```

## CloudFormation Template additions
To use the auto-created S3 Buckets in your Cloudformation add the following Parameter and
IAM Role Policy to your template to allow CodeDeploy running on instances access to your
newly created S3 buckets.

Parameters
```
"CodeDeployBucketName": {
  "Type": "String",
  "Description": "Base name of the S3 Bucket used for CodeDeploy",
  "Default": "example-project-builds"
}
```

Instance Role Policy:
```
{
    "PolicyName": "CodeDeployBuildAccess",
    "PolicyDocument": {
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": {"Fn::Join": ["", ["arn:aws:s3:::" {"Ref": "CodeDeployBucketName"}, "-", { "Ref": "AWS::Region" } , "/*"]]}
        }]
    }
}
```
