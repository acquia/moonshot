# CLI Commands

## List

List stacks for this application.

|Description|Long Form|Short Form|Type|Example|Default|
|---|---|---|---|---|---|
|Parent stack to import parameters from|--parent|-p|string|moonshot-database-sample-app|None|
|Choose if code should be deployed after stack is created|deploy|d|boolean||true|
|Show all stack events during update. When present, it will show all events|show_all_events||boolean||Errors only|
|Environment Name|name|n|string|moonshot-sample-app|None|
|Interactive Logger|interactive_logger||boolean||true|
|Verbose|verbose|v|boolean||false|


Example:
```shell
moonshot list
```

Output:

```shell
my-service-staging
my-service-dev-user1
my-service-dev-user2
my-service-prod
```

## Create
Create a new environment.

|Description|Long Form|Short Form|Type|Example|Default|
|---|---|---|---|---|---|
|Parent stack to import parameters from|parent|p|string|moonshot-database-sample-app|None|
|Choose if code should be deployed after stack is created|deploy|d|boolean||true|
|Show all stack events during update. When present, it will show all events|show_all_events||boolean||Errors only|
|Environment Name|name|n|string|moonshot-sample-app|None|
|Interactive Logger|interactive_logger||boolean||true|
|Verbose|verbose|v|boolean||false|

Example:

```shell
moonshot create --name my-service-staging
```

Output:

```shell
[ ✓ ] [ 0m 0s ] Loading stack parameters file '/home/user/project/cloud_formation/parameters/my-service-staging.yml'.
[ ✓ ] [ 0m 0s ] Setting stack parameter overrides:
[ ✓ ] [ 0m 0s ]    ArtifactBucket: my-service-staging
[ ✓ ] [ 0m 0s ]    AvailabilityZone1: us-east-1a
[ ✓ ] [ 0m 0s ]    AvailabilityZone2: us-east-1d
[ ✓ ] [ 0m 0s ]    DesiredCapacity: 1
[ ✓ ] [ 0m 1s ] Created CloudFormation Stack my-service-staging.
[ ✓ ] [ 4m 49s ] CloudFormation Stack my-service-staging successfully created.
[ ✓ ] [ 0m 0s ] Created CodeDeploy Application my-service-staging.
[ ✓ ] [ 0m 1s ] Created CodeDeploy Deployment Group my-service-staging.
[ ✓ ] [ 0m 1s ] AutoScaling Group up to capacity!
[ ✓ ] [ 0m 0s ] Build script bin/build.sh exited successfully!
[ ✓ ] [ 0m 1s ] Uploaded s3://my-service-staging/my-service-staging-1457657945.tar.gz successfully.
[ ✓ ] [ 0m 49s ] Deployment d-UNF7JW2KE completed successfully!
```


## Update

Update the CloudFormation stack within an environment.

@todo: Add more description here as to what it exactly does.

Options:

|Description|Long Form|Short Form|Type|Example|Default|
|---|---|---|---|---|---|
|Parent stack to import parameters from|--parent|-p|string|moonshot-database-sample-app|None|
|Show all stack events during update. When present, it will show all events|show_all_events||boolean||Errors only|
|Environment Name|name|n|string|moonshot-sample-app|None|
|Interactive Logger|interactive_logger||boolean||true|
|Verbose|verbose|v|boolean||false|

Example:

```shell
moonshot update --name my-service-staging
```

Output:

```shell
[ ✓ ] [ 0m 1s ] Initiated update for CloudFormation Stack my-service-staging.
[ ✓ ] [ 6m 11s ] CloudFormation Stack my-service-staging successfully updated.
[ ✓ ] [ 0m 0s ] CodeDeploy Application my-service-staging already exists.
[ ✓ ] [ 0m 0s ] CodeDeploy CodeDeploy Deployment Group my-service-staging already exists.
[ ✓ ] [ 0m 1s ] AutoScaling Group up to capacity!
```

## Status

Get the status of an existing environment.

|Description|Long Form|Short Form|Type|Example|Default|
|---|---|---|---|---|---|
|Environment Name|name|n|string|moonshot-sample-app|None|
|Interactive Logger|interactive_logger||boolean||true|
|Verbose|verbose|v|boolean||false|

Example:

```shell
moonshot status --name my-service-staging
```

Output:

```shell
┌─ CodeDeploy Application: my-service-staging
│
│ Application and Deployment Group are configured correctly.
│
└──
CloudFormation Stack my-service-staging exists.
┌─ Stack Parameters
│
│ ArtifactBucket:    my-service-bucket  (overridden)
│ AvailabilityZone1: us-east-1a               (overridden)
│ AvailabilityZone2: us-east-1d               (overridden)
│ DesiredCapacity:   1                        (overridden)
│
├─ Stack Outputs
│
│ URL: http://sample-LoadBala-VA232FB9FWFZ-1573168493.us-east-1.elb.amazonaws.com
│
├─ ASG: AutoScalingGroup
│
│ Name: my-service-staging-AutoScalingGroup-104IA9X5MF7GH
│ Using ELB health checks, with a 600s health check grace period.
│ Desired Capacity is 1 (Min: 1, Max: 5).
│ Has 1 Load Balancer(s): sample-LoadBala-VA232FB9FWFZ
│
├── Instances
│
│  i-5607c6cd 52.90.68.26 InService Healthy 0d 0h 8m 11s (launch config up to date)
│
├── Recent Activity
│
│  2016-03-11 01:07:59 UTC Terminating EC2 instance: i-73fe99f7     Successful 100%
│  2016-03-11 01:03:26 UTC Launching a new EC2 instance: i-5607c6cd Successful 100%
│  2016-03-11 00:58:03 UTC Launching a new EC2 instance: i-73fe99f7 Successful 100%
│
└──
```


## Push

Create a development build from the working directory, and deploy it.

|Description|Long Form|Short Form|Type|Example|Default|
|---|---|---|---|---|---|
|Environment Name|name|n|string|moonshot-sample-app|None|
|Interactive Logger|interactive_logger||boolean||true|
|Verbose|verbose|v|boolean||false|

Example:

```shell
moonshot deploy-code --name my-service-staging
```

Output:

```shell
[ ✓ ] [ 0m 1s ] Build script bin/build.sh exited successfully!
[ ✓ ] [ 0m 1s ] Uploaded s3://my-service-staging/my-service-staging-1457658789.tar.gz successfully.
[ ✓ ] [ 1m 28s ] Deployment d-PFMNSB5KE completed successfully!
```

## Build

Build a tarball of the software, ready for deployment.
Requires a version name parameter.

|Description|Long Form|Short Form|Type|Example|Default|
|---|---|---|---|---|---|
|Environment Name|name|n|string|moonshot-sample-app|None|
|Interactive Logger|interactive_logger||boolean||true|
|Verbose|verbose|v|boolean||false|

Example:

```shell
moonshot build 1.0.0
```

Output:

```shell
[ ✓ ] [ 0m 0s ] Build script bin/build.sh exited successfully!
[ ✓ ] [ 0m 1s ] Uploaded s3://my-service-staging/1.0.0.tar.gz successfully.
```

## Deploy

Deploy a versioned release created with the `build` command.
Requires a version name parameter.

|Description|Long Form|Short Form|Type|Example|Default|
|---|---|---|---|---|---|
|Environment Name|name|n|string|moonshot-sample-app|None|
|Interactive Logger|interactive_logger||boolean||true|
|Verbose|verbose|v|boolean||false|

Example:

```shell
moonshot deploy 1.0.0
```

Output:

```shell
[ ✓ ] [ 1m 0s ] Deployment d-M4FY304KE completed successfully!
```

## Delete

Delete an existing environment.

|Description|Long Form|Short Form|Type|Example|Default|
|---|---|---|---|---|---|
|Show all stack events during update. When present, it will show all events|show_all_events||boolean||Errors only|
|Environment Name|name|n|string|moonshot-sample-app|None|
|Interactive Logger|interactive_logger||boolean||true|
|Verbose|verbose|v|boolean||false|

Example:

```shell
moonshot delete --name my-service-staging
```

Output:

```shell
[ ✓ ] [ 0m 1s ] Initiated deletion of CloudFormation Stack my-service-staging.
[ ✓ ] [ 11m 50s ] CloudFormation Stack my-service-staging successfully deleted.
[ ✓ ] [ 0m 0s ] Deleted CodeDeploy Application 'my-service-staging'.
```

## Doctor
Run configuration checks against current environment. Throws an error
if one or more checks failed.  For example, if you are using a
deployment_mechanism that is using S3, it will check if the bucket
actually exists and that you have access to. Each mechanism is able to
add checks themselves that will be recognized and run.

|Description|Long Form|Short Form|Type|Example|Default|
|---|---|---|---|---|---|
|Environment Name|name|n|string|moonshot-sample-app|None|
|Interactive Logger|interactive_logger||boolean||true|
|Verbose|verbose|v|boolean||false|

Example:

```shell
moonshot doctor
```

Output:

```shell
Stack
  ✓ CloudFormation template found at '/home/user/project/cloud_formation/my-service.json'.
  ✓ CloudFormation template is valid.

Script
  ✓ Script 'bin/build.sh' exists.

S3Bucket
  ✓ Bucket 'my-service-staging' exists.
  ✓ Bucket is writable, new builds can be uploaded.

CodeDeploy
  ✓ CodeDeployRole exists.
  ✓ Resource 'AutoScalingGroup' exists in the CloudFormation template.
```

## SSH

SSH into the first or specified instance on the stack.

|Description|Long Form|Short Form|Type|Example|Default|
|---|---|---|---|---|---|
|SSH user name|user|l|string|someuser|Environment variable: MOONSHOT_SSH_USER or USER|
|Private key file for SSH|identity-file|i|string|~/.ssh/whatever|Environment variable: MOONSHOT_SSH_KEY_FILE|
|Instance ID|instance|s|string|i-04683a82f2dddcc04|(first)|
|Command to execute|command|c|string|uname -a|open a shell|
|Auto Scaling Group|auto-scaling-group|g|string|ExampleAppAsg||
|Environment Name|name|n|string|moonshot-sample-app|None|
|Interactive Logger|interactive_logger||boolean||true|
|Verbose|verbose|v|boolean||false|

Example:

```shell
moonshot ssh --name my-service-staging -i ~/.ssh/whatever -c "cat /etc/redhat-release"
```

Output:

```shell
Opening SSH connection to i-04683a82f2dddcc04 (123.123.123.123)...
CentOS Linux release 7.2.1511 (Core)
Connection to 123.123.123.123 closed.
```
