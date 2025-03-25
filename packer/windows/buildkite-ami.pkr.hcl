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
  default = "m7i.xlarge"
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

data "amazon-ami" "windows-server-2022" {
  filters = {
    name                = "Windows_Server-2022-English-Full-Base-*"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = var.region
}

source "amazon-ebs" "elastic-ci-stack" {
  ami_description = "Buildkite Elastic Stack (Windows Server 2022 w/ docker)"
  ami_groups      = ["all"]
  ami_name        = "buildkite-stack-windows-${replace(timestamp(), ":", "-")}"
  communicator    = "winrm"
  instance_type   = var.instance_type
  region          = var.region
  source_ami      = data.amazon-ami.windows-server-2022.id
  user_data_file  = "scripts/ec2-userdata.ps1"
  winrm_insecure  = true
  winrm_use_ssl   = true
  winrm_username  = "Administrator"

  launch_block_device_mappings {
    volume_type           = "gp3"
    device_name           = "/dev/sda1"
    volume_size           = 30
    delete_on_termination = true
  }

  tags = {
    Name          = "elastic-ci-stack-windows"
    OSVersion     = "Windows Server 2022"
    BuildNumber   = var.build_number
    AgentVersion  = var.agent_version
    IsReleased    = var.is_released
    SourceAMIID   = data.amazon-ami.windows-server-2022.id
    SourceAMIName = data.amazon-ami.windows-server-2022.name
  }
}

build {
  sources = ["source.amazon-ebs.elastic-ci-stack"]

  provisioner "file" {
    destination = "C:/packer-temp"
    source      = "conf"
  }

  provisioner "file" {
    destination = "C:/packer-temp"
    source      = "../../plugins"
  }

  provisioner "powershell" {
    script = "scripts/install-utils.ps1"
  }

  provisioner "powershell" {
    script = "scripts/install-cloudwatch-agent.ps1"
  }

  provisioner "powershell" {
    script = "scripts/install-lifecycled.ps1"
  }

  provisioner "powershell" {
    script = "scripts/enable-containers.ps1"
  }

  // need to restart after enabling containers
  // for some reason the restart provisioner does not wait for the previous provisioner to finish
  // so we pause for some amount of time
  provisioner "windows-restart" {
    pause_before = "10s"
  }

  provisioner "powershell" {
    script = "scripts/install-docker.ps1"
  }

  provisioner "powershell" {
    script = "scripts/install-buildkite-agent.ps1"
  }

  provisioner "powershell" {
    script = "scripts/install-s3secrets-helper.ps1"
  }

  provisioner "powershell" {
    script = "scripts/install-session-manager-plugin.ps1"
  }

  provisioner "powershell" {
    inline = ["Remove-Item -Path C:/packer-temp -Recurse"]
  }

  provisioner "powershell" {
    script = "scripts/configure-ec2launch.ps1"
  }
}
