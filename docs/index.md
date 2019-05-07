# <img src="logo.png" width="48"> Moonshot
_Because releasing services shouldn't be a moonshot._

## Overview

Moonshot is a command line tool and library for provisioning and
managing application environments using CloudFormation. It has native
support for integration with S3 and CodeDeploy, as well. Other systems
may be added using our pluggable system. The core components are:

- A DeploymentMechanism controls releasing code. For example, Amazon
  CodeDeploy.
- A BuildMechanism creates a release artifact. For example, a local
  shell script.
- A ArtifactRepository stores the release artifacts. For example,
  Amazon S3.

![General Flow](moonshot.png "General Flow")

## Design Goals

The goal of Moonshot is to wrap CloudFormation in a toolchain that
codifies the deployment and management of a service. Our goal is that
within a given service the Moonshot configuration, CloudFormation
template, and supporting AWS services should be easily understood.

Some of our original design goals were:

- Simplicity: It shouldn't take more than a few hours to understand what your
  release tooling does.
- Choice: As much as possible, each component should be pluggable and omittable,
  so teams are free to use what works best for them.
- Verbosity: The output of core Moonshot code should explain in detail what
  changes are being made, so knowledge is shared and not abstracted.

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
your specific use-case. We aren't trying to solve every use case, but
rather give you an extensible toolkit that your project can grow with,
without leaving your trapped behind rigid design philosophy.
Interested in how it can be used? See our [example documentation][2].
The example doc uses the files shown in the [sample directory][3] so
you can figure out how to modify this for your own application.

We also want to [help you contribute and answer all your questions][1]
on how Moonshot is maintained.

[1]: http://moonshot.readthedocs.org/en/latest/about/contribute
[2]: example.md
[3]: https://github.com/acquia/moonshot/tree/master/sample

## Requirements

- Ruby 2.2 or higher

## Attributions

Thanks to [Acquia Inc.](https://acquia.com) for sponsoring the time to work on this tool.
Thanks to [Ted](https://github.com/tottey) for the funky logo.
