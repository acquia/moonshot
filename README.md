# <img src="docs/logo.png" width="48"> Moonshot [![Documentation Status](https://readthedocs.org/projects/moonshot/badge/?version=latest)](http://moonshot.readthedocs.org/en/latest/?badge=latest)[![Build Status](https://travis-ci.org/acquia/moonshot.svg?branch=master)](https://travis-ci.org/acquia/moonshot)[![Test Coverage](https://codeclimate.com/github/acquia/moonshot/badges/coverage.svg)](https://codeclimate.com/github/acquia/moonshot/coverage)[![Code Climate](https://codeclimate.com/github/acquia/moonshot/badges/gpa.svg)](https://codeclimate.com/github/acquia/moonshot)[![Gem Version](https://badge.fury.io/rb/moonshot.svg)](https://badge.fury.io/rb/moonshot)
_Because releasing services shouldn't be a moonshot._

## Overview

[We also have pretty docs, lots more to find there.](http://moonshot.readthedocs.org/en/latest/)

Moonshot is a Ruby gem for provisioning environments in AWS using a CLI.
The environments are centered around a single CloudFormation stack and supported
by pluggable systems:

- A DeploymentMechanism controls releasing code.
- A BuildMechanism creates a release artifact.
- A ArtifactRepository stores the release artifacts.

![General Flow](docs/moonshot.png "General Flow")

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

Install the Moonshot gem:

```shell
$ gem install moonshot
```

After installation, there is still some work required. Follow the [example documentation](docs/example.md) as described below to dig in!

## Getting started

The Moonshot tool has been designed to be an extensible library for your
specific use-case. Interested in how it can be used? See our [example
documentation](http://moonshot.readthedocs.org/en/latest/example). The example
doc uses the files shown in the [sample
directory](https://github.com/acquia/moonshot/tree/master/sample) so you can
figure out how to modify this for your own deployment strategy.

We also want to [help you contribute and answer all your questions](http://moonshot.readthedocs.org/en/latest/about/contribute) on how Moonshot is maintained.

## Requirements

- Ruby 2.5 or higher

## Attributions

Thanks to [Acquia Inc.](https://acquia.com) for sponsoring the time to work on this tool.
Thanks to [Ted](https://github.com/tottey) for the funky logo.
