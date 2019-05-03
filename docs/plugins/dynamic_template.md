# Dynamic template plugin

## Overview
The dynamic template plugin can be used to generate CloudFormation plugins
on-the-fly. This is useful for properties that can't be set via parameters,
like "DeletionPolicy". The plugin is using ERB templating and it's also
available in the form of a CLI.

## Usage and configuration

The plugin accepts three configuration parameters:
- `source`: path to the source template file
- `parameters`: key-value pairs of the parameters of your choice
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
