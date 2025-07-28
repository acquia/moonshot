# BuildMechanism

## Script

The Script BuildMechanism will execute a local shell script, with certain
expectations. The script will run with some environment variables:

- `VERSION`: The named version string passed to `build-version`.
- `OUTPUT_FILE`: The file that the script is expected to produce.

If the file is not created by the build script, deployment will
fail. Otherwise, the output file will be uploaded using the
ArtifactRepository.

Sample Usage
```ruby
Moonshot.config do |c|
  c.build_mechanism = Script.new('bin/build.sh')
...
```

## GithubRelease

A build mechanism that creates a tag and GitHub release. Could be used
to delegate other building steps after GitHub release is created.

Sample Usage

```ruby
Moonshot.config do |c|
  c.build_mechanism = GithubRelease.new
...
```

**skip_ci_status** is an optional flag. It would allow us to skip checks 
on the commit's CI job status. Without this option, the GithubRelease mechanism will wait until the build is finished.

Sample Usage

```ruby
Moonshot.config do |c|
  c.build_mechanism = GithubRelease.new
...
```
Also a command-line option is available to override this value.

	Usage: moonshot build VERSION
	    -v, --[no-]verbose               Show debug logging
	    -s, --skip-ci-status             Skip checks on CI jobs
	    -n, --environment=NAME           Which environment to operate on.
		--[no-]interactive-logger    Enable or disable fancy logging
	    -F, --foo

## Version Proxy

@Todo Document and clarify the use-case of the Version Proxy.
