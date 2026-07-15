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

variable "cis_source_ami" {
  type        = string
  description = "When set, use this CIS-hardened AMI as the source instead of the standard AL2023 AMI lookup."
  default     = ""
}

# Latest minimal Amazon Linux 2023 image for the given arch
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

locals {
  is_cis     = var.cis_source_ami != ""
  source_ami = local.is_cis ? var.cis_source_ami : data.amazon-ami.al2023.id
  ami_prefix = local.is_cis ? "buildkite-base-cis-linux" : "buildkite-base-linux"
  ami_desc   = local.is_cis ? "Buildkite Golden Base (CIS AL2023 w/ docker)" : "Buildkite Golden Base (Amazon Linux 2023 w/ docker)"
  os_version = local.is_cis ? "CIS Amazon Linux 2023" : "Amazon Linux 2023"
  component  = local.is_cis ? "buildkite-base-cis" : "buildkite-base"
}

source "amazon-ebs" "buildkite-base-ami" {
  ami_description                           = local.ami_desc
  ami_groups                                = var.ami_public ? ["all"] : []
  ami_users                                 = var.ami_public ? [] : var.ami_users
  ami_name                                  = "${local.ami_prefix}-${var.arch}-${replace(timestamp(), ":", "-")}"
  instance_type                             = var.instance_type
  region                                    = var.region
  source_ami                                = local.source_ami
  ssh_username                              = "ec2-user"
  ssh_clear_authorized_keys                 = true
  temporary_security_group_source_public_ip = true

  launch_block_device_mappings {
    volume_type           = "gp3"
    device_name           = "/dev/xvda"
    volume_size           = local.is_cis ? 15 : 10
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  imds_support = "v2.0"

  tags = {
    Name        = "${local.ami_prefix}-${var.arch}"
    OSVersion   = local.os_version
    BuildNumber = var.build_number
    IsReleased  = var.is_released
    SourceAMIID = local.source_ami
    Component   = local.component
  }
}

build {
  sources = ["source.amazon-ebs.buildkite-base-ami"]

  provisioner "file" {
    destination = "/tmp"
    source      = "conf"
  }

  provisioner "file" {
    destination = "/tmp/conf/"
    source      = "../shared/conf/"
  }

  provisioner "file" {
    destination = "/tmp/"
    source      = "scripts/versions.sh"
  }

  # Essential utilities & updates
  provisioner "shell" {
    script        = "scripts/install-utils.sh"
    remote_folder = "/var/tmp"
  }

  # Docker engine
  provisioner "shell" {
    script        = "scripts/install-docker.sh"
    remote_folder = "/var/tmp"
  }

  # CloudWatch agent
  provisioner "shell" {
    script        = "scripts/install-cloudwatch-agent.sh"
    remote_folder = "/var/tmp"
  }

  # Session Manager plugin
  provisioner "shell" {
    script        = "scripts/install-session-manager-plugin.sh"
    remote_folder = "/var/tmp"
  }

  # Clean up
  provisioner "shell" {
    script        = "../shared/scripts/cleanup.sh"
    remote_folder = "/var/tmp"
  }
}
