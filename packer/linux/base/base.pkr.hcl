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
  description = "Base Linux distribution to build on: amazonlinux2023 or ubuntu2404."
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

# Latest Ubuntu 24.04 (Noble) image for the given arch. Ubuntu AMI names use
# amd64/arm64 whereas var.arch is x86_64/arm64. Owner 099720109477 is Canonical.
data "amazon-ami" "ubuntu" {
  filters = {
    architecture        = var.arch
    name                = "ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-${var.arch == "x86_64" ? "amd64" : "arm64"}-server-*"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"]
  region      = var.region
}

locals {
  os_distro_name = {
    amazonlinux2023 = "Amazon Linux 2023"
    ubuntu2404      = "Ubuntu 24.04"
  }
  source_ami = {
    amazonlinux2023 = data.amazon-ami.al2023.id
    ubuntu2404      = data.amazon-ami.ubuntu.id
  }
  ssh_username = {
    amazonlinux2023 = "ec2-user"
    ubuntu2404      = "ubuntu"
  }
  # Ubuntu root volume is /dev/sda1; AL2023 is /dev/xvda
  root_device_name = {
    amazonlinux2023 = "/dev/xvda"
    ubuntu2404      = "/dev/sda1"
  }
}

source "amazon-ebs" "buildkite-base-ami" {
  ami_description                           = "Buildkite Golden Base (${local.os_distro_name[var.os_distro]} w/ docker)"
  ami_groups                                = var.ami_public ? ["all"] : []
  ami_users                                 = var.ami_public ? [] : var.ami_users
  ami_name                                  = "buildkite-base-linux-${var.os_distro}-${var.arch}-${replace(timestamp(), ":", "-")}"
  instance_type                             = var.instance_type
  region                                    = var.region
  source_ami                                = local.source_ami[var.os_distro]
  ssh_username                              = local.ssh_username[var.os_distro]
  ssh_clear_authorized_keys                 = true
  temporary_security_group_source_public_ip = true

  launch_block_device_mappings {
    volume_type           = "gp3"
    device_name           = local.root_device_name[var.os_distro]
    volume_size           = 10
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  imds_support = "v2.0"

  tags = {
    Name        = "buildkite-base-linux-${var.os_distro}-${var.arch}"
    OSVersion   = local.os_distro_name[var.os_distro]
    Distro      = var.os_distro
    BuildNumber = var.build_number
    IsReleased  = var.is_released
    SourceAMIID = local.source_ami[var.os_distro]
    Component   = "buildkite-base"
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

  provisioner "file" {
    destination = "/tmp/"
    source      = "../shared/scripts/distro.sh"
  }

  # Essential utilities & updates
  provisioner "shell" {
    environment_vars = ["OS_DISTRO=${var.os_distro}"]
    script           = "scripts/install-utils.sh"
  }

  # Docker engine
  provisioner "shell" {
    environment_vars = ["OS_DISTRO=${var.os_distro}"]
    script           = "scripts/install-docker.sh"
  }

  # CloudWatch agent
  provisioner "shell" {
    environment_vars = ["OS_DISTRO=${var.os_distro}"]
    script           = "scripts/install-cloudwatch-agent.sh"
  }

  # Session Manager plugin
  provisioner "shell" {
    environment_vars = ["OS_DISTRO=${var.os_distro}"]
    script           = "scripts/install-session-manager-plugin.sh"
  }

  # Clean up
  provisioner "shell" {
    environment_vars = ["OS_DISTRO=${var.os_distro}"]
    script           = "../shared/scripts/cleanup.sh"
  }
}
