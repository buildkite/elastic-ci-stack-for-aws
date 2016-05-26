provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_s3_bucket" "buildkite_artifacts" {
  bucket = "${var.name}-artifacts"
  acl = "private"
  force_destroy = true

  lifecycle_rule {
    prefix = "*"
    enabled = true

    expiration {
      days = "${var.artifact_retention}"
    }
  }
}

resource "aws_s3_bucket" "buildkite_secrets" {
  bucket = "${var.name}-secrets"
  acl = "private"
  force_destroy = true
}

resource "aws_cloudformation_stack" "buildkite" {
  name = "${var.name}Stack"
  template_url = "https://s3.amazonaws.com/buildkite-aws-stack/aws-stack.json"
  capabilities = ["CAPABILITY_IAM"]

  parameters {
    KeyName = "${var.key_name}"
    BuildkiteOrgSlug = "${var.buildkite_org_slug}"
    BuildkiteAgentToken = "${var.buildkite_agent_token}"
    BuildkiteApiAccessToken = "${var.buildkite_api_access_token}"
    SecretsBucket = "${aws_s3_bucket.buildkite_secrets.id}"
    ArtifactsBucket = "${aws_s3_bucket.buildkite_artifacts.id}"
    InstanceType = "${var.instance_type}"
    MaxSize = "${var.max_size}"
    MinSize = "${var.min_size}"
    RootVolumeSize = "${var.volume_size}"
    ImageId = "${var.image_id}"
    AvailabilityZones = "${var.region}"
  }
}

output "secrets_bucket" {
  value = "aws_s3_bucket.buildkite_secrets.id"
}

output "artifacts_bucket" {
  value = "aws_s3_bucket.buildkite_artifacts.id"
}
