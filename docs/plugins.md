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
- setup_create
- setup_update
- setup_status
- setup_build
- setup_deploy
- setup_delete


The method will be handed a single argument, which is an instance of the
`Moonshot::Resources` class. This instance gives the plugin access to three
important resources:

- `Moonshot::Resources#ilog` is an instance of `InteractiveLogger`, used to
display status to the user of the CLI interface.
- `Moonshot::Resources#stack` is an instance of `Moonshot::Stack` which can
retreive the name of the stack, stack parameters and stack outputs. This support
should be expanded in the future to provide Plugins with more control over the
CloudFormation stack.

`setup` hooks work a bit differently. They are invoked before any other business
logic is executed. This means no resource objects are actually instantiated,
therefore no parameters are passed in this case.

## Manipulating CLI options with Plugins

If you wish to modify the options accepted by a core Moonshot command
in order to affect the pre/post hooks defined in your plugin,
implement a method called `<action>_cli_hook`. This hook will be
passed an instance of OptionParser, which you can manipulate and
return. For example:

```ruby
class MyPlugin
  def pre_build(_)
    puts "FULL SPEED AHEAD!!!!" if @hyperdrive
  end

  def build_cli_hook(parser)
    parser.on('--foo', '-F', TrueClass, 'ENABLE HYPERDRIVE') do |v|
      @hyperdrive = v
    end
  end
end
```

With this plugin, the output of `moonshot build --help` reflects the
new command line option:

```
Usage: moonshot build VERSION
    -v, --[no-]verbose               Show debug logging
    -s, --skip-ci-status             Skip checks on CI jobs
    -n, --environment=NAME           Which environment to operate on.
        --[no-]interactive-logger    Enable or disable fancy logging
    -F, --foo                        ENABLE HYPERDRIVE
```

## Adding a plugin to Moonshot

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
