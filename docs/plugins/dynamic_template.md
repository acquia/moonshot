# Dynamic template plugin

## Overview
The dynamic template plugin can be used to generate CloudFormation plugins
on-the-fly. This is useful for properties that can't be set via parameters,
like "DeletionPolicy". The plugin is using ERB templating and it's also
available in the form of a CLI.

## Usage and configuration

The plugin accepts three configuration parameters:
- `source`: path to the source template file
- `parameters`: parameters of your choice (see below - [parameters](#parameters))
- `destination`: the target file path

Your template must be conforming the ERB standards. You can use both
`<%= deletion_policy %>` and `<%= @deletion_policy %>` formats in your template.

## Example
```ruby
Moonshot::Plugins::DynamicTemplate.new(
  source: 'cloud_formation/cdb-api.erb',
  parameters: { deletion_policy: 'Retain' },
  destination: 'cloud_formation/cdb-api.json'
)
```

## Parameters

The 'hack' with lambdas created for the cases when you need to read
CLI parameters before running the plugin.

Parameters could be described in two ways:
* key-value pairs
  ```ruby
  parameters: { deletion_policy: 'Retain' }
  ```

* lambdas
  ```ruby
  parameters = -> environment_name {
  environment = environment_name =~ prod_regexp ? 'prod' : 'dev'
  parameters = YAML.load_file("cloud_formation/parameters/#{environment}.yml")
  }
  ```
