packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "arch" {
  type    = string
  default = "x86_64"
}

variable "instance_type" {
  type    = string
  default = "m7a.xlarge"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "build_number" {
  type    = string
  default = "none"
}

variable "agent_version" {
  type    = string
  default = "devel"
}

variable "is_released" {
  type    = bool
  default = false
}

variable "ami_public" {
  type        = bool
  description = "Whether to make the AMI publicly available to all AWS users. Defaults to false for security."
  default     = false
}

variable "ami_users" {
  type        = list(string)
  description = "List of AWS account IDs that should have access to the AMI when ami_public is false."
  default     = []
}

data "amazon-ami" "al2023" {
  filters = {
    architecture        = var.arch
    name                = "al2023-ami-minimal-*"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = var.region
}

# Optional override for building from a pre-baked “golden base” AMI
variable "base_ami_id" {
  type    = string
  default = ""
}

variable "is_cis" {
  type        = bool
  description = "Whether we are building on a CIS-hardened base AMI. Adjusts volume size and naming."
  default     = false
}

locals {
  ami_prefix = var.is_cis ? "buildkite-stack-cis-linux" : "buildkite-stack-linux"
  ami_desc   = var.is_cis ? "Buildkite Elastic Stack (CIS AL2023 w/ docker)" : "Buildkite Elastic Stack (Amazon Linux 2023 w/ docker)"
  os_version = var.is_cis ? "CIS Amazon Linux 2023" : "Amazon Linux 2023"
  component  = var.is_cis ? "elastic-ci-stack-cis" : "elastic-ci-stack"
}

source "amazon-ebs" "elastic-ci-stack-ami" {
  ami_description                           = local.ami_desc
  ami_groups                                = var.ami_public ? ["all"] : []
  ami_users                                 = var.ami_public ? [] : var.ami_users
  ami_name                                  = "${local.ami_prefix}-${var.arch}-${replace(timestamp(), ":", "-")}"
  instance_type                             = var.instance_type
  region                                    = var.region
  source_ami                                = var.base_ami_id
  ssh_username                              = "ec2-user"
  ssh_clear_authorized_keys                 = true
  temporary_security_group_source_public_ip = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  imds_support = "v2.0"

  launch_block_device_mappings {
    volume_type           = "gp3"
    device_name           = "/dev/xvda"
    volume_size           = var.is_cis ? 15 : 10
    delete_on_termination = true
  }

  run_tags = {
    Name = "Packer Builder" // marks resources for deletion in cleanup.sh
  }

  tags = {
    Name         = "${local.component}-linux-${var.arch}"
    OSVersion    = local.os_version
    BuildNumber  = var.build_number
    AgentVersion = var.agent_version
    IsReleased   = var.is_released
    SourceAMIID  = var.base_ami_id
    Component    = local.component
  }
}

build {
  sources = ["source.amazon-ebs.elastic-ci-stack-ami"]

  provisioner "file" {
    destination = "/tmp"
    source      = "conf"
  }

  provisioner "file" {
    destination = "/tmp/conf"
    source      = "../shared/conf/"
  }

  provisioner "file" {
    destination = "/tmp/plugins"
    source      = "../../../plugins"
  }

  provisioner "file" {
    destination = "/tmp/build"
    source      = "../../../build"
  }

  provisioner "file" {
    destination = "/tmp/"
    source      = "../base/scripts/versions.sh"
  }

  provisioner "shell" {
    script        = "scripts/configure-cloudwatch-agent.sh"
    remote_folder = "/var/tmp"
  }

  provisioner "shell" {
    script        = "scripts/install-buildkite-agent.sh"
    remote_folder = "/var/tmp"
  }

  provisioner "shell" {
    script        = "scripts/install-buildkite-utils.sh"
    remote_folder = "/var/tmp"
  }

  provisioner "shell" {
    script        = "../shared/scripts/cleanup.sh"
    remote_folder = "/var/tmp"
  }
}
