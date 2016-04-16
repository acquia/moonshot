# Including Moonshot-based tooling in your project

## Create a Moonfile.rb

(TODO: Implement `moonshot init`)

In the root of your project, create a file called `Moonfile.rb` with
the following contents:

```ruby
Moonshot.config do |c|
  c.application_name = 'my-service'
  c.artifact_repository = S3Bucket.new('my-service-builds')
  c.build_mechanism = Script.new('build/script.sh')
  c.deployment_mechanism = CodeDeploy.new(asg: 'AutoScalingGroup')
end
```

This example assumes:
- You have a CloudFormation JSON template in folder called "cloud_formation/my-service.json".
- You have an S3 bucket called "my-service-builds".
- You have a script in "script/build.sh" that will build a tarball output.tar.gz.
- You have a working CodeDeploy setup, including the CodeDeployRole.

If all that is true, you can now deploy your software to a new stack with:
```
$ moonshot create
```

By default, you'll get a development environment named `my-service-dev-giraffe`,
where `giraffe` is your username. If you want to provision test or production
named environment, use:
```
$ moonshot create -n my-service-staging
$ moonshot create -n my-service-production
```

By default, create launches the stack and deploys code. If you want to only
create the stack and not deploy code, use:
```
$ moonshot create --no-deploy
```

If you make changes to your application and want to release a development build
to your stack, run:
```
$ moonshot push
```

To build a "named build" for releasing through test and production environments,
use:
```
$ moonshot build v0.1.0
$ moonshot deploy v0.1.0 -n <environment-name>
```

We recommend using a CI system like Jenkins to perform those activities, for
consistency.
