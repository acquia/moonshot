# Global Options

## `--[no-]interactive-logger`

*Default: Enabled*

Use this option to disable the animated logger. The logger is also
disabed automatically in environments where STDIN is not a tty, such
as Jenkins.

## `--[no-]verbose / -v`

*Default: Disabled*

Display debug logging. The types of things logged here are mostly
useful only for core Moonshot developers, or if you are working on
custom plugins.

## `--skip-ci-status / -s`

*Default: Disabled*

It would allow us to skip checks on the commit's CI job status. 
Without this option, the GithubRelease mechanism will wait until the build is finished.

#### `--environment=NAME / -n NAME`

*Default: dev-$USER, or as specified in the `environment_name`
configuration option in `Moonfile.rb`.*

Set the application's environment, such as jsmith1 or production. This
is used to configure the CloudFormation Stack name. Not all commands
make use of this option.

# Core Commands

## `moonshot new`

Creates a new Moonshot application with the necessary directory structure and sample files.

Example:
```shell
moonshot new my_application
```

## `moonshot list`

List stacks for this application. At this time, there are no
additional options for this command. All stacks in the current region
are displayed.

### Example Output

```shell
┌─ Environment List
│
│ dev-johnsmith  2016-08-03 13:38:43 UTC UPDATE_COMPLETE
│ dev-johnsmith2 2016-10-19 21:00:47 UTC ROLLBACK_COMPLETE
│ dev-johnsmith3 2016-10-19 22:34:35 UTC UPDATE_COMPLETE
│ dev-johnsmith4 2016-10-22 13:10:36 UTC ROLLBACK_COMPLETE
│ peter1         2016-10-10 00:01:29 UTC UPDATE_COMPLETE
│ peter2         2016-10-14 01:56:33 UTC UPDATE_COMPLETE
│
└──
```

## `moonshot create`

Create a new environment. The user is prompted for any missing
parameters, or for any parameters not set by parent stacks, answer
files or on the command line that they may want to change the default
value of.

### Options

## `--[no-]show-all-events`

*Default: Disabled*

By default, Moonshot show only error CloudFormation events during the
`create`, `update`, and `delete` actions. With this enabled, all
events are displayed to the screen. This can be quite noisy, but also
helpful if you want to see where your stack updates are taking the
most time, for example.

#### `--parent=STACK_NAME / -p STACK_NAME`

*Default: `parents_stacks` configuration option in `Moonfile.rb`,
which defaults to no parent stacks.*

If set, this CloudFormation Stack will be used as a source of Stack
Parameters, where each Output is mapped to an input Parameter on this
CloudFormation Stack. As with all command-line options this will
overwrite any configuration in `Moonfile.rb`.

#### `--[no-]interactive`

*Default: Interactive prompting enabled.*

If `--no-interactive` is specified, the user will not be prompted for
any unspecified stack parameters. If any stack parameters are missing,
an error message will be displayed at Moonshot will exit with status
code 1. This is a useful option for continuous integration
environments.

#### `--answer-file=FILE / -a FILE`

*Default: No answer file is used.*

This can be used to reference a YAML file containing values which
should be used for stack parameters. This overrides default values,
but has a lower precedent than the `-P` option (below). This is a
useful option for automated environments, such as end-to-end test
suites.

#### `--parameter=KEY=VALUE / -P KEY=VALUE`

*Default: None.*

*Note: May be specified multiple times.*

This can be used to set stack parameters on the command line. They
have a higher priority than parameters found in the answer file
specified with the `--answer-file` option.

#### `--[no-]deploy / -d`

*Default: Run deployment immediately after stack creation.*

If disabled, no deployment will be run after stack creation. Note that
depending on your stack configuration, this may trigger, for example,
ELB failures which will result in instance replacements.

### Example Output

```shell
[ ✓ ] [ 0m 1s ] Created CloudFormation Stack my-service-jsmith1.
[ ✓ ] [ 4m 49s ] CloudFormation Stack my-service-jsmith1 successfully created.
[ ✓ ] [ 0m 0s ] Created CodeDeploy Application my-service-jsmith1.
[ ✓ ] [ 0m 1s ] Created CodeDeploy Deployment Group my-service-jsmith1.
[ ✓ ] [ 0m 1s ] AutoScaling Group up to capacity!
[ ✓ ] [ 0m 0s ] Build script bin/build.sh exited successfully!
[ ✓ ] [ 0m 1s ] Uploaded s3://my-service-builds/my-service-jsmith1-1457657945.tar.gz successfully.
[ ✓ ] [ 0m 49s ] Deployment d-UNF7JW2KE completed successfully!
```

## `moonshot update`

Update an environment with the latest local CloudFormation template
using a ChangeSet. Keep all existing parameters, unless they are
specified by `--answer-file` and/or `--parameter`. If there are new
parameters in the template and they are not specified, the user will
be prompted for their values, unless `--no-interactive` is specified,
in which case an error will be displayed.

The user is prompted interactively to accept the ChangeSet, unless
`--no-interactive` is set. `--force` can be specified to automatically
accept the changes. If `--dry-run` is set, the changes are
automatically rejected after being displayed, which can be useful for
seeing what the impact of a template change might be in a given
environment.

### Options

#### `--answer-file=FILE / -a FILE`

See [create][#moonshot-create].

#### `--parent=STACK_NAME / -p STACK_NAME`

See [create][#moonshot-create].

#### `--parameter=KEY=VALUE / -P KEY=VALUE`

See [create][#moonshot-create].

#### `--[no-]show-all-events`

See [create][#moonshot-create].

#### `--force`

Automatically accept the ChangeSet that was generated, without
prompting the user. The changes are still displayed in the log
output.

#### `--dry-run`

Automatically reject the ChangeSet that was generated, after
displaying the changes.

### Examples

Update a single Stack parameter, using the latest template:

```shell
moonshot update -n env-name -P NumInstances=4
```

Update multiple Stack parameters using a YAML-formatted answer file:

```shell
moonshot update -n prod --answer-file updates.yml
```

### Example Output

Output:

```shell
[ ✓ ] [ 0m 1s ] Initiated update for CloudFormation Stack my-service-staging.
[ ✓ ] [ 6m 11s ] CloudFormation Stack my-service-staging successfully updated.
[ ✓ ] [ 0m 0s ] CodeDeploy Application my-service-staging already exists.
[ ✓ ] [ 0m 0s ] CodeDeploy CodeDeploy Deployment Group my-service-staging already exists.
[ ✓ ] [ 0m 1s ] AutoScaling Group up to capacity!
```

## `moonshot status`

### Example

```shell
moonshot status --name staging
```

### Example Output

```shell
┌─ CodeDeploy Application: my-service-staging
│
│ Application and Deployment Group are configured correctly.
│
└──
CloudFormation Stack my-service-staging exists.
┌─ Stack Parameters
│
│ ArtifactBucket:    my-service-bucket
│ AvailabilityZone1: us-east-1a
│ AvailabilityZone2: us-east-1d
│ DesiredCapacity:   1
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

## `moonshot push`

Create a development build from the working directory, and deploy it.

### Example

```shell
moonshot deploy-code --name my-service-staging
```

### Example Output

```shell
[ ✓ ] [ 0m 1s ] Build script bin/build.sh exited successfully!
[ ✓ ] [ 0m 1s ] Uploaded s3://my-service-staging/my-service-staging-1457658789.tar.gz successfully.
[ ✓ ] [ 1m 28s ] Deployment d-PFMNSB5KE completed successfully!
```

## `moonshot build VERSION`

Build a tarball of the software, ready for deployment. Requires a
version name parameter.

### Example

```shell
moonshot build 1.0.0
```

### Example Output

```shell
[ ✓ ] [ 0m 0s ] Build script bin/build.sh exited successfully!
[ ✓ ] [ 0m 1s ] Uploaded s3://my-service-staging/1.0.0.tar.gz successfully.
```

## `moonshot deploy VERSION`

Deploy a versioned release created with the `build` command. Requires
a version name parameter.

### Example

```shell
moonshot deploy 1.0.0
```

### Example Output

```shell
[ ✓ ] [ 1m 0s ] Deployment d-M4FY304KE completed successfully!
```

## `moonshot delete`

Delete an existing environment.

### Options

#### `--[no-]show-all-events`

See [create][#moonshot-create].

### Example

```shell
moonshot delete --name staging
```

### Example Output

```shell
[ ✓ ] [ 0m 1s ] Initiated deletion of CloudFormation Stack my-service-staging.
[ ✓ ] [ 11m 50s ] CloudFormation Stack my-service-staging successfully deleted.
[ ✓ ] [ 0m 0s ] Deleted CodeDeploy Application 'my-service-staging'.
```

## `moonshot doctor`

Run configuration checks against current environment. Throws an error
if one or more checks failed.  For example, if you are using a
deployment_mechanism that is using S3, it will check if the bucket
actually exists and that you have access to. Each mechanism is able to
add checks themselves that will be recognized and run.

### Example Output

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

## `moonshot ssh`

SSH into the first or specified instance on the stack. If your
environment has more than one Auto Scaling Group, the target Auto
Scaling Group must be specified with the `--auto-scaling-group`
option.

### Options

#### `--user USERNAME / -l USERNAME`

*Default: None, uses SSH commands default behavior.*

*Environment Variable: MOONSHOT_SSH_USER.*

The user to authenticate to the remote host as.

#### `--identity-file FILE / -i FILE`

*Default: None, uses SSH commands default behavior.*

*Environment Variable: MOONSHOT_SSH_KEY_FILE.*

An SSH private key to use for authentication.

#### `--instance INSTANCE_ID / -s INSTANCE_ID`

*Default: Use the first instance in the Auto Scaling Group.*

If specified, the instance ID will be used instead of determining the
first available instance automatically.

#### `--command COMMAND / -c COMMAND`

*Default: Open an interactive SSH session.*

If specified, run the command instead of opening an interactive SSH
session.

#### `--auto-scaling-group NAME / -g NAME`

*Default: Use only Auto Scaling Group, or fail if multiple Auto
Scaling Groups are present in Stack.*

This option is **required** if there is more than one Auto Scaling
Group in your environment.

### Example

```shell
moonshot ssh --name staging -i ~/.ssh/whatever -c "cat /etc/redhat-release"
```

### Example Output

```shell
Opening SSH connection to i-04683a82f2dddcc04 (123.123.123.123)...
CentOS Linux release 7.2.1511 (Core)
Connection to 123.123.123.123 closed.
```
