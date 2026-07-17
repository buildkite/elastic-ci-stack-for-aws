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

variable "os_distro" {
  type        = string
  description = "Base Linux distribution the base AMI was built on: amazonlinux2023 or ubuntu2404."
  default     = "amazonlinux2023"
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

# Optional override for building from a pre-baked “golden base” AMI
variable "base_ami_id" {
  type    = string
  default = ""
}

locals {
  os_distro_name = {
    amazonlinux2023 = "Amazon Linux 2023"
    ubuntu2404      = "Ubuntu 24.04"
  }
  ssh_username = {
    amazonlinux2023 = "ec2-user"
    ubuntu2404      = "ubuntu"
  }
  # Must match the base AMI's root device (Ubuntu /dev/sda1, AL2023 /dev/xvda)
  root_device_name = {
    amazonlinux2023 = "/dev/xvda"
    ubuntu2404      = "/dev/sda1"
  }
}

source "amazon-ebs" "elastic-ci-stack-ami" {
  ami_description                           = "Buildkite Elastic Stack (${local.os_distro_name[var.os_distro]} w/ docker)"
  ami_groups                                = var.ami_public ? ["all"] : []
  ami_users                                 = var.ami_public ? [] : var.ami_users
  ami_name                                  = "buildkite-stack-linux-${var.os_distro}-${var.arch}-${replace(timestamp(), ":", "-")}"
  instance_type                             = var.instance_type
  region                                    = var.region
  source_ami                                = var.base_ami_id
  ssh_username                              = local.ssh_username[var.os_distro]
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
    device_name           = local.root_device_name[var.os_distro]
    volume_size           = 10
    delete_on_termination = true
  }

  run_tags = {
    Name = "Packer Builder" // marks resources for deletion in cleanup.sh
  }

  tags = {
    Name         = "elastic-ci-stack-linux-${var.os_distro}-${var.arch}"
    OSVersion    = local.os_distro_name[var.os_distro]
    Distro       = var.os_distro
    BuildNumber  = var.build_number
    AgentVersion = var.agent_version
    IsReleased   = var.is_released
    SourceAMIID  = var.base_ami_id
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

  provisioner "file" {
    destination = "/tmp/"
    source      = "../shared/scripts/distro.sh"
  }

  provisioner "shell" {
    environment_vars = ["OS_DISTRO=${var.os_distro}"]
    script           = "scripts/configure-cloudwatch-agent.sh"
  }

  provisioner "shell" {
    environment_vars = ["OS_DISTRO=${var.os_distro}"]
    script           = "scripts/install-buildkite-agent.sh"
  }

  provisioner "shell" {
    environment_vars = ["OS_DISTRO=${var.os_distro}"]
    script           = "scripts/install-buildkite-utils.sh"
  }

  provisioner "shell" {
    environment_vars = ["OS_DISTRO=${var.os_distro}"]
    script           = "../shared/scripts/cleanup.sh"
  }
}
