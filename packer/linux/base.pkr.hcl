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

source "amazon-ebs" "buildkite-base-ami" {
  ami_description                           = "Buildkite Golden Base (Amazon Linux 2023 w/ docker)"
  ami_groups                                = ["all"]
  ami_name                                  = "buildkite-base-linux-${var.arch}-${replace(timestamp(), ":", "-")}"
  instance_type                             = var.instance_type
  region                                    = var.region
  source_ami                                = data.amazon-ami.al2023.id
  ssh_username                              = "ec2-user"
  ssh_clear_authorized_keys                 = true
  temporary_security_group_source_public_ip = true

  launch_block_device_mappings {
    volume_type           = "gp3"
    device_name           = "/dev/xvda"
    volume_size           = 10
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  imds_support = "v2.0"

  tags = {
    Name        = "buildkite-base-linux-${var.arch}"
    OSVersion   = "Amazon Linux 2023"
    BuildNumber = var.build_number
    IsReleased  = var.is_released
    SourceAMIID = data.amazon-ami.al2023.id
    Component   = "buildkite-base"
  }
}

build {
  sources = ["source.amazon-ebs.buildkite-base-ami"]

  provisioner "file" {
    destination = "/tmp"
    source      = "conf"
  }


  # Essential utilities & updates
  provisioner "shell" {
    script = "scripts/install-utils.sh"
  }

  # Docker engine
  provisioner "shell" {
    script = "scripts/install-docker.sh"
  }

  # CloudWatch agent
  provisioner "shell" {
    script = "scripts/install-cloudwatch-agent.sh"
  }

  # Session Manager plugin
  provisioner "shell" {
    script = "scripts/install-session-manager-plugin.sh"
  }

  # Clean up
  provisioner "shell" {
    script = "scripts/cleanup.sh"
  }
}
