variable "access_key" {
  default = ""
  description = "The AWS access key"
}

variable "secret_key" {
  default = ""
  description = "The AWS secret key"
}

variable "region" {
  default = "us-east-1"
  description = "The AWS region"
}

variable "name" {
  description = "Name of the stack"
  name = "buildkite"
}

variable "image_id" {
  description = "The AMI to use"
  default = "ami-1dc83e70"
}

variable "key_name" {
  description = "The ssh keypair used to access the buildkite instances"
}

variable "buildkite_org_slug" {
  description = "Your Buildkite organization's slug"
}

variable "buildkite_agent_token" {
  description = "Your Buildkite organization's agent token"
}

variable "buildkite_api_access_token" {
  description = "A Buildkite API access token (with read_pipelines, read_builds and read_agents) used for gathering metrics"
}

variable "instance_type" {
  description = "The type of instance to use for the agent"
  default = "t2.nano"
}

variable "max_size" {
  description = "The maximum number of agents to launch"
  default = 10
}

variable "min_size" {
  description = "The minumum number of agents to launch"
  default = 0
}

variable "volume_size" {
  description = "Size of EBS volume for root filesystem in GB"
  default = 250
}

variable "artifact_retention" {
  description = "Number of days to retain artifacts"
  default = 9
}

