# <img src="logo.png" width="48"> Moonshot
_Because releasing services shouldn't be a moonshot._

## Overview

Moonshot is a Ruby gem for provisioning environments in AWS using a CLI.
The environments are centered around a single CloudFormation stack and supported
by pluggable systems:

- A DeploymentMechanism controls releasing code.
- A BuildMechanism creates a release artifact.
- A ArtifactRepository stores the release artifacts.

![General Flow](moonshot.png "General Flow")

## Design Goals

These are core ideas to the creation of this project. Not all are met to the
level we'd like (e.g. CloudFormation isn't much of a Choice currently), but we
should aspire to meet them with each iteration.

- Simplicity: It shouldn't take more than a few hours to understand what your
  release tooling does.
- Choice: As much as possible, each component should be pluggable and omittable,
  so teams are free to use what works best for them.
- Verbosity: The output of core Moonshot code should explain in detail what
  changes are being made, so knowledge is shared and not abstracted.

## Existing limitations

- Moonshot does not support detailed error logging from Cloudformation substacks.
- Moonshot does not support a non-local cloudformation file.

## Installation

You can install Moonshot for your local user with:

    $ gem install moonshot

If you would prefer to manage your projects dependencies with Bundler,
add the following to your Gemfile:

    gem 'moonshot'

And then execute:

    $ bundle install

After installation, there is still some work required. Follow
the [example documentation](example.md) as described below to dig in!

## Getting started

The Moonshot tool has been designed to be an extensible library for
your specific use-case. Interested in how it can be used? See
our [example documentation](example.md). The example doc uses the
files shown in the
[sample directory](https://github.com/acquia/moonshot/tree/master/sample) so
you can figure out how to modify this for your own deployment
strategy.

We also want to [help you contribute and answer all your questions][1]
on how Moonshot is maintained.

[1]: http://moonshot.readthedocs.org/en/latest/about/contribute

## Requirements

- Ruby 2.1 or higher

## Attributions

Thanks to [Acquia Inc.](https://acquia.com) for sponsoring the time to work on this tool.
Thanks to [Ted](https://github.com/tottey) for the funky logo.
