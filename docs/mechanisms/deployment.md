# DeploymentMechanism

## CodeDeploy

The CodeDeploy DeploymentMechanism will create a CodeDeploy Application and Deployment Group matching the application name. The created Deployment Group will point at the logical resource id provided to the constructor (e.g. `CodeDeploy.new(asg: 'MyAutoScalingGroup')`). During the `deploy-code` action, the ArtifactRepository is checked for compatibility with CodeDeploy. Currently only the S3Bucket is supported, though CodeDeploy itself supports deploying from a git source.

Assumptions made by the CodeDeploy mechanism:

- You are using an S3Bucket ArtifactRepository.
- Your build artifact contains an appspec.yml file.

Sample Usage
```ruby
#!/usr/bin/env ruby

require 'moonshot'

# Set up Moonshot tooling for our environment.
class MoonshotSampleApp < Moonshot::CLI
  self.deployment_mechanism = CodeDeploy.new(asg: 'AutoScalingGroup', role: 'CodeDeployRole', app_name: 'my_app_name', config_name: 'CodeDeployDefault.OneAtATime')
...
```
Parameters

### asg | string

The logical name of the AutoScalingGroup to create and manage a Deployment
Group for in CodeDeploy.

### role | string

IAM role with AWSCodeDeployRole policy. CodeDeployRole is considered as default role if its not specified.

### app_name | string,nil

The name of the CodeDeploy Application and Deployment Group. By default, this is the same as the stack name, and probably what you want. If you have multiple deployments in a single Stack, they must have unique names.

### config_name | string

The name of the Deplloyment Configuration. CodeDeployDefault.OneAtATime is the default if its not specified.

For more information about CodeDeploy, see the [AWS Documentation][1].


[1]: http://docs.aws.amazon.com/codedeploy/latest/userguide/welcome.html
