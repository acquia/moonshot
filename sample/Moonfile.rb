Moonshot.config do |m|
  m.app_name = 'moonshot-sample-app'
  m.artifact_repository = S3Bucket.new('moonshot-sample-bucket2')
  m.build_mechanism = Script.new('bin/build.sh')
  m.deployment_mechanism = CodeDeploy.new(asg: 'AutoScalingGroup')
end
