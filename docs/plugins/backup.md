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

- `bucket`: the name of the S3 bucket you wish to upload the tarball (optional)
- `buckets`: a hash map containing account aliases as keys, and target buckets as values (optional).
- `files`: an array of relative path names as strings.
- `backup_parameters`: boolean value for backing up all parameters into a YAML file (optional, defaults to `false`).
- `backup_template`: boolean value for backing up the current CloudFormation template (optional, defaults to `false`).
- `hooks`: which hooks to run the backup logic, works with all valid Moonshot hooks
- `target_name`: tarball archive name (optional, defaults to `<app_name>_<timestamp>_<user>.tar.gz`).

You must provide either `bucket` or `buckets`, but **not both**.

If you provide either `backup_parameters` or `backup_template` you may not provide `files` additionally.

`pre_create` and `post_delete` hooks are **not** allowed to use due to certain implementation restrictions.

## Default method

If you wish to back up only the current template and parameter files, you can simply
use the factory method provided:

```ruby
Moonshot.config do |c|
  # ...
  c.plugins << Moonshot::Plugins::Backup.to_bucket('your-bucket-name')
```

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
  c.plugins << Backup.new do |b|
    b.bucket = 'your-bucket-name'

    b.files = [
      'cloud_formation/%{app_name}.json',
      'cloud_formation/parameters/%{stack_name}.yml'
    ]

    b.hooks = [:post_create, :post_update]
  end
```

```ruby
  c.plugins << Backup.new do |b|
    b.buckets = {
      'dev_account' => 'dev_bucket',
      'prod_account' => 'prod_bucket'
    }

    b.backup_template = true
    b.backup_parameters = true

    b.hooks = [:post_create, :post_update]
  end
```
