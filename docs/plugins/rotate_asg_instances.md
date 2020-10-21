# Rotate ASG Instances Plugin

## Overview
The rotate ASG instances plugin rotates the outdated instances in Auto Scaling Groups. It compares the launch configuration and sees if any outdated instances are present. It detaches the instances first then shuts down the instance and waits for a new instance to replace the outdated one in ASG then proceeds to the next outdated instance.

After all outdated instances are shutdown successfully, it terminates them and reaps the associated volumes.

## Usage
It allows gracefully shutting down each instance instead of terminating them and killing all the running processes.

## Configuration
The plugin uses config.ssh_config.ssh_user value for logging into the ASG instances to shutdown. The value should be the username with which you have the access to the instances.

The plugin accepts additional configuration from config.ssh_config.ssh_options for ssh.

## Example
```ruby
Moonshot.config do |c|
  # ...
  c.plugins << Moonshot::Plugins::RotateAsgInstances.new
  # ...
end
```
