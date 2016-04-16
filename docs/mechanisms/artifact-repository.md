# ArtifactRepository

## S3Bucket

The store action will upload the file using the S3 PutObject API call.
The local environment must be configured with appropriate
credentials. Running `doctor` will verify those credentials for you.

To create a new S3Bucket ArtifactRepository:
```ruby
Moonshot.config do |c|
  c.artifact_repository = S3Bucket.new('my-bucket-name')
end
```

## S3BucketViaGithubReleases

S3 Bucket repository backed by GitHub releases. If a SemVer package
isn't found in S3, it is downloaded from GitHub releases to avoid not
being able to release in case there is trouble with AWS S3.

To create a new S3BucketViaGithubReleases ArtifactRepository:
```ruby
Moonshot.config do |c|
  c.artifact_repository = S3BucketViaGithubReleases.new('my-bucket-name')
end
```
