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

data "amazon-ami" "al2023" {
  filters = {
    architecture        = var.arch
    name                = "al2023-ami-minimal-2023.5.20240903.0-*"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = var.region
}

source "amazon-ebs" "elastic-ci-stack-ami" {
  ami_description                           = "Buildkite Elastic Stack (Amazon Linux 2023 w/ docker)"
  ami_groups                                = ["all"]
  ami_name                                  = "buildkite-stack-linux-${var.arch}-${replace(timestamp(), ":", "-")}"
  instance_type                             = var.instance_type
  region                                    = var.region
  source_ami                                = data.amazon-ami.al2023.id
  ssh_username                              = "ec2-user"
  ssh_clear_authorized_keys = true
  temporary_security_group_source_public_ip = true

  run_tags = {
    Name = "Packer Builder" // marks resources for deletion in cleanup.sh
  }

  tags = {
    Name          = "elastic-ci-stack-linux-${var.arch}"
    OSVersion     = "Amazon Linux 2023"
    BuildNumber   = var.build_number
    AgentVersion  = var.agent_version
    IsReleased    = var.is_released
    SourceAMIID   = data.amazon-ami.al2023.id
    SourceAMIName = data.amazon-ami.al2023.name
  }
}

build {
  sources = ["source.amazon-ebs.elastic-ci-stack-ami"]

  provisioner "file" {
    destination = "/tmp"
    source      = "conf"
  }

  provisioner "file" {
    destination = "/tmp/plugins"
    source      = "../../plugins"
  }

  provisioner "file" {
    destination = "/tmp/build"
    source      = "../../build"
  }

  provisioner "shell" {
    script = "scripts/install-utils.sh"
  }

  provisioner "shell" {
    script = "scripts/install-cloudwatch-agent.sh"
  }

  provisioner "shell" {
    script = "scripts/install-docker.sh"
  }

  provisioner "shell" {
    script = "scripts/install-buildkite-agent.sh"
  }

  provisioner "shell" {
    script = "scripts/install-buildkite-utils.sh"
  }
}
