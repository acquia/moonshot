# Auto-Scaling Group LaunchConfig Rollout Tool

## Overview

This plugin adds support for rolling out changes to Auto Scaling
Groups that have happened after a stack update. It supports various
pre- and post-actions on the instances (using Moonshot's native SSH
support).

## Example

The ASGRollout class is intended to be used within a method in your
project's derived class of the Moonshot::CLI class.

```ruby
#!/usr/bin/env ruby

require 'moonshot'

class MyService < Moonshot::CLI
  # .. normal configuration ..

  desc :asg_rollout, 'Update instances in the Auto Scaling Group'
  def asg_rollout
    ar = Moonshot::Tools::ASGRollout.new do |config|
      config.controller = controller
      config.logical_id = 'APIAutoScalingGroup'

      # Trigger the worker process to initiate a clean shutdown.
      config.predetach = -> { 0 == exec('systemctl stop my-worker-1') }

      # Wait for that clean shutdown to happen.
      config.terminate_when = -> { 0 == exec('pgrep -f my-worker-1') }
    end
    ar.run!
  end
end

MyService.start
```

## Configuration

The ASGRollout object accepts two required keyword arguments:
  - **controller**: A Moonshot::Controller. If you are using
    Moonshot::CLI the `controller` method is most often when you want
    to use.
  - **logical_id**: The Logical resource ID from the CloudFormation
    stack to operate on.

By default, the ASGRollout class will build a list of instances with
non-conforming LaunchConfiguration, then one at a time perform the
following actions:
  1. Increase the *Max* and *Desired* sizes of the Auto Scaling Group by one.
  2. Wait for the new instance to be *InService*.
  3. Detach a non-conforming instance.
  4. Wait for the instance to be *OutOfService* or removed from the
     Auto Scaling Group.
  5. If the Auto Scaling Group has an associated Elastic Load
     Balancer, wait for the instance to be *Todo?* there as well.
  6. Wait for a new instance to replace it.
  7. Wait for that new instance to be *InService* in the Auto Scaling Group.
  8. If the Auto Scaling Group has an associated Elastic Load
     Balancer, wait for the instance to be *InService* there as well.
  9. Terminate the detached non-conforming instance.
  10. If there are other non-conforming instances, go to
     step 3.
  11. Restore the *Max* and *Desired* sizes of the Auto Scaling Group
      to their original values.

A number of optional parameters change the behavior to suit your
project's needs:
  - **pre_detach** *(Callable)*: This will be run before step 3
    above. If it returns `false`, the process will be aborted.
  - **terminate** *(Callable)*: This will be run to execute step 9. If
    not specified, the default is to use EC2's Terminate API.
  - **terminate_when** *(Callable)*: This will be run every 5 seconds
    prior to step 9. Step 9 will continue as soon as this returns
    `true`.
  - **terminate_when_timeout** *(Integer)*: (Default 300s) Number of seconds to
    wait for the terminate_when lambda to return true. After this
    timeout, the process will be aborted.

For the lambda / callables above, they are evaluated in a context with
the following methods available:
  - **exec** *(TODO)*: Run a command on the instance and return the
    exit code.
  - **ec2** *(Aws::EC2::Client)*: A configured Aws::EC2::Client for the region we're
    operating in.
  - **instance_id** *(String)*: The EC2 instance ID.
