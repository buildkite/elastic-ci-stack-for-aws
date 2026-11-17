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

variable "os_version" {
  type        = string
  description = "Windows Server version to build on: 2022 or 2025."
  default     = "2022"

  validation {
    condition     = contains(["2022", "2025"], var.os_version)
    error_message = "The os_version value must be 2022 or 2025."
  }
}

variable "instance_type" {
  type    = string
  default = "c8a.xlarge"
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

variable "iam_instance_profile" {
  type        = string
  description = "Optional instance profile for the Windows image build instance."
  default     = ""
}

# Latest Windows Server AMI for the given version. For 2025 this is AWS's
# default image, which boots UEFI and so needs a Nitro instance type; the name
# does not match the legacy "BIOS-" 2025 images.
data "amazon-ami" "windows-server" {
  filters = {
    name                = "Windows_Server-${var.os_version}-English-Full-Base-*"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = var.region
}

locals {
  # 2022 keeps its original unversioned names; later versions add a suffix.
  name_suffix = var.os_version == "2022" ? "" : "-${var.os_version}"
  os_version  = "Windows Server ${var.os_version}"
}

source "amazon-ebs" "buildkite-base" {
  ami_description = "Buildkite Golden Base (${local.os_version} w/ docker)"
  ami_groups      = var.ami_public ? ["all"] : []
  ami_users       = var.ami_public ? [] : var.ami_users
  ami_name        = "buildkite-base-windows${local.name_suffix}-${replace(timestamp(), ":", "-")}"
  communicator    = "winrm"
  instance_type   = var.instance_type
  region          = var.region
  source_ami      = data.amazon-ami.windows-server.id
  user_data_file  = "../shared/scripts/ec2-userdata.ps1"
  winrm_insecure  = true
  winrm_use_ssl   = true
  winrm_port      = 5986
  winrm_timeout   = "20m"
  winrm_username  = "Administrator"

  iam_instance_profile = var.iam_instance_profile

  launch_block_device_mappings {
    volume_type           = "gp3"
    device_name           = "/dev/sda1"
    volume_size           = 30
    delete_on_termination = true
  }

  # The amazon plugin also copies run_tags to the AMI and its snapshots. `tags`
  # below overwrites Name, BuildNumber and Purpose there, but ManagedBy stays,
  # so never select builders by ManagedBy alone.
  run_tags = {
    Name        = "Packer Builder" // cleanup.sh and cleanup-packer.sh match builders on this
    ManagedBy   = "elastic-ci-stack-for-aws"
    Purpose     = "disposable-ci"
    BuildNumber = var.build_number
  }

  tags = {
    Name        = "buildkite-base-windows${local.name_suffix}"
    Purpose     = "ami"
    OSVersion   = local.os_version
    BuildNumber = var.build_number
    IsReleased  = var.is_released
    SourceAMIID = data.amazon-ami.windows-server.id
    Component   = "buildkite-base"
  }
}

build {
  sources = ["source.amazon-ebs.buildkite-base"]

  provisioner "file" {
    destination = "C:/packer-temp"
    source      = "scripts"
  }

  provisioner "file" {
    destination = "C:/Windows/Temp/"
    source      = "scripts/versions.ps1"
  }

  provisioner "file" {
    destination = "C:/Windows/Temp/"
    source      = "../../trust"
  }

  provisioner "powershell" {
    scripts = [
      "scripts/remediate-trust.ps1",
      "scripts/install-utils.ps1",
      "scripts/install-cloudwatch-agent.ps1",
      "scripts/install-lifecycled.ps1",
      "scripts/enable-containers.ps1"
    ]
  }

  # Install Containers once, then let Packer initiate and wait for the reboot.
  provisioner "windows-restart" {
    restart_timeout = "20m"
    timeout         = "20m"
  }

  provisioner "powershell" {
    scripts = [
      "scripts/install-docker.ps1",
      "scripts/install-session-manager-plugin.ps1"
    ]
  }

  # Independently verify installation before allowing this base to be published.
  provisioner "powershell" {
    script = "scripts/validate-docker.ps1"
  }

  # Cleanup and sysprep
  provisioner "powershell" {
    inline = [
      "Remove-Item -Path C:/packer-temp -Recurse",
      "& 'C:/Program Files/Amazon/EC2Launch/EC2Launch.exe' sysprep --shutdown true --clean true"
    ]
  }
}
