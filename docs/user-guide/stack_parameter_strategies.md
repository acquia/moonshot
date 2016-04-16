# Stack Parameter strategies

Currently used, valid strategy types are:
- `default`
- `merge`

Strategy type can be set both via command line, or overriding
the default behaviour in your `Moonshot::CLI` subclass.

**Command line:** `bin/environment update --parameter-strategy=merge`

**Inline:** `parameter_strategy :merge`

Accepted both as a string or a symbol.

Setting precedence is the following:
- command line option
- inline default behaviour override
- falling back to `default`

## Default strategy

Default strategy is the legacy behaviour, works exactly as previously,
prior to introducing different strategies. Each parameter is loaded from the
parameter file (eg. `cloud_formation/parameters/environment-name.yml`),
and *all of them* are overridden on update.

**Word of caution:** when using this strategy we encourage you to keep all
per-environment tunings in the source repository acting as both a safety net
and documentation of existing environments. A possible solution for using this
strategy in a safe manner is the following:

When a stack update is performed, a *parameter file* is checked in
`cloud_formation/parameters/environment-name.yml`. This file is YAML formatted
and takes a hash of stack parameter names and values, for example:
```yaml
---
AsgDesiredCap: 12
AsgMaxCap: 15
ELBCertificate: iam::something:star_example_com
```

If a file exists, it's used every time a CloudFormation change request is sent,
so no configuration can revert back to defaults through this tool. It's highly
recommended that you add these files back to source control as soon as possible
and be in the habit of pulling latest changes before applying any infrastructure
updates.

## Merge strategy

Merge strategy is a new way of dealing with stack parameters on stack update.
You only have to declare **parameters you want to update** in your parameter file,
the remaining parameters are not updated, meaning it stays as it's current uploaded (live) state.
This behaviour is achived by using CloudFormation's `UsePreviousValue` feature.
This way you can avoid accidentally reverting parameter values with your outdated local
parameter file.

# Defining custom parameter strategy class
Defining and using your own custom parameter strategy class is possible if you are
using Moonshot without the provided CLI. A parameter strategy class is a class which responds
to a method called `parameters`. It receives two parameters: the first contains a hash
of the existing, currently deployed stack parameters, the second one (also a hash) contains
the parameters defined in the parameters file. The method should return an array of
hashes of the following format:

```json
{
  parameter_key: key,
  parameter_value: value,
  use_previous_value: false
}
```

You either supply a value for `parameter_value` or set
`use_previous_value` to `true`, which leaves the parameter as it
currently is.

Example:

```ruby
class CustomStrategy
  def parameters(parameters, stack_parameters, template)
    parameters.map do |k, v|
      {
        parameter_key: k,
        parameter_value: v,
        use_previous_value: false
      }
    end
  end
end
```

In order to use your custom strategy class, set a new instance of your
class to `ControllerConfig`'s `parameter_strategy` attribute.
