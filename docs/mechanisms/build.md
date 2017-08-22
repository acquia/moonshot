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
  wait_for_travis_mechanism = TravisDeploy.new("acquia/moonshot", true)
  c.build_mechanism = GithubRelease.new(wait_for_travis_mechanism)
...
```

**skip_ci_status** is an optional flag. It would allow us to skip checks 
on the commit's CI job status. Without this option, the GithubRelease mechanism will wait until the build is finished.

Sample Usage

```ruby
Moonshot.config do |c|
  wait_for_travis_mechanism = TravisDeploy.new("acquia/moonshot", true)
  c.build_mechanism = GithubRelease.new(wait_for_travis_mechanism, skip_ci_status: true)
...
```
Also a command-line option is available to override this value.

	Usage: moonshot build VERSION
	    -v, --[no-]verbose               Show debug logging
	    -s, --skip-ci-status             Skip checks on CI jobs
	    -n, --environment=NAME           Which environment to operate on.
		--[no-]interactive-logger    Enable or disable fancy logging
	    -F, --foo    

## TravisDeploy

The Travis Build Mechanism waits for Travis-CI to finish building a
job matching the VERSION (see above) and the output of the travis job
has to be 'BUILD=1'. Can be used to make sure that the travis job for
the repository for that version actually finished before the
deployment step can be executed.

Sample Usage
```ruby
Moonshot.config do |c|
  # First argument is the repository as known by travis.
  # Second argument is wether or not you are using travis pro.
  c.build_mechanism = TravisDeploy.new("acquia/moonshot", pro: true)
...
```

## Version Proxy

@Todo Document and clarify the use-case of the Version Proxy.
