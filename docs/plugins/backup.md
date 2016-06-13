# Moonshot backup plugin

Moonshot plugin for backing up config files.

## Functionality

The plugin collects and deflates certain files to a single tarball,
and uploads that to a a given S3 bucket. The whole process happens
in memory, nothing is written to disk. The plugin currently supports single files only, 
including whole directories in your tarball is not possible yet.

The plugin uses the Moonshot AWS config, meaning that the bucket must be
present in the same account and region as your deployment.

## Basic usage

When instantiating a class, you need to set the following options
in a block, where the object is provided as a block argument:

- `bucket`: the name of the S3 bucket you wish to upload the tarball
- `files`: a hash with two mandatory and one mandatory value:
  - `path` (mandatory): file path as an array, relative to the base path
  - `name` (mandatory): name of the file
  - `permission` (optional): permission in the target tarball, defaults to `0644`
- `hooks`: which hooks to run the backup logic, works with all valid Moonshot hooks
- `target_name`: tarball archive name, default: `<app_name>_<timestamp>_<user>.tar.gz`

## Placeholders

You can use the following placeholders both in your filenames
and tarball target names (meanings are pretty self explaining):

- `%{app_name}`
- `%{stack_name}`
- `%{timestamp}`
- `%{user}`

## Example

A possible use-case is backing up a CF template and/or
parameter file after create or update.

```ruby
plugin(
  Backup.new do |b|
    b.bucket = 'acquia-cloud-database-test'
    b.files = [
      { path: %w(cloud_formation), name: '%{app_name}.json' },
      { path: %w(cloud_formation parameters), name: '%{stack_name}.yml' }
    ]
    b.hooks = [:post_create, :post_update]
  end
)
```