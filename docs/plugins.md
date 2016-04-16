# Plugin Support

**Warning, the plugin support in Moonshot is a work-in-progress. The interface
to plugins may change dramatically in future versions.**


Moonshot supports adding plugins (implemented as a Ruby class) to the
controller that can perform actions before and after the `create`,
`update`, `delete`, `deploy`, `status`, `doctor` and `ssh` actions.

## Writing a Moonshot Plugin

A Moonshot Plugin is a Ruby class that responds to one or more of the following
methods:

- pre_create
- post_create
- pre_update
- post_update
- pre_delete
- post_delete
- pre_deploy
- post_deploy
- pre_status
- post_status
- pre_doctor
- post_doctor
- pre_ssh
- post_ssh

The method will be handed a single argument, which is an instance of the
`Moonshot::Resources` class. This instance gives the plugin access to three
important resources:

- `Moonshot::Resources#ilog` is an instance of `InteractiveLogger`, used to
display status to the user of the CLI interface.
- `Moonshot::Resources#stack` is an instance of `Moonshot::Stack` which can
retreive the name of the stack, stack parameters and stack outputs. This support
should be expanded in the future to provide Plugins with more control over the
CloudFormation stack.

## Adding a plugin to a CLI tool.

Once you have defined or included your plugin class, you can add a
plugin by modifying your `Moonfile.rb` file, like so:

```ruby
Moonshot.config do |c|
  c.app_name = 'my-app'
  # ...
  c.plugins << MyPlugin.new
end
```

## Auto-loading Plugin Source

The Moonshot CLI tool will auto-load plugin source in the path
`moonshot/plugins/**/*.rb` relative to the `Moonfile.rb` file for your
project. This can be useful for plugins that define project-specific
behaviors.
