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
  description = "Windows Server version the base AMI was built on: 2022 or 2025."
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

variable "agent_version" {
  type    = string
  default = "devel"
}

variable "is_released" {
  type    = bool
  default = false
}

# Optional override for building from a pre-baked “golden base” AMI
variable "base_ami_id" {
  type    = string
  default = ""
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

locals {
  # 2022 keeps its original unversioned names; later versions add a suffix.
  name_suffix = var.os_version == "2022" ? "" : "-${var.os_version}"
  os_version  = "Windows Server ${var.os_version}"
}

source "amazon-ebs" "elastic-ci-stack" {
  ami_description = "Buildkite Elastic Stack (${local.os_version} w/ docker)"
  ami_groups      = var.ami_public ? ["all"] : []
  ami_users       = var.ami_public ? [] : var.ami_users
  ami_name        = "buildkite-stack-windows${local.name_suffix}-${replace(timestamp(), ":", "-")}"
  communicator    = "winrm"
  instance_type   = var.instance_type
  region          = var.region
  # Allow golden-base override
  source_ami     = var.base_ami_id
  user_data_file = "../shared/scripts/ec2-userdata.ps1"
  winrm_insecure = true
  winrm_use_ssl  = true
  winrm_port     = 5986
  winrm_timeout  = "20m"
  winrm_username = "Administrator"

  iam_instance_profile = var.iam_instance_profile

  launch_block_device_mappings {
    volume_type           = "gp3"
    device_name           = "/dev/sda1"
    volume_size           = 30
    iops                  = 6000
    throughput            = 500
    delete_on_termination = true
  }

  # Keep the faster builder storage settings out of the output AMI's launch defaults.
  ami_block_device_mappings {
    volume_type           = "gp3"
    device_name           = "/dev/sda1"
    volume_size           = 30
    iops                  = 3000
    throughput            = 125
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
    Name         = "elastic-ci-stack-windows${local.name_suffix}"
    Purpose      = "ami"
    OSVersion    = local.os_version
    BuildNumber  = var.build_number
    AgentVersion = var.agent_version
    IsReleased   = var.is_released
    SourceAMIID  = var.base_ami_id
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
    source      = "scripts"
  }

  provisioner "file" {
    destination = "C:/packer-temp"
    source      = "../../../plugins"
  }

  provisioner "file" {
    destination = "C:/Windows/Temp/"
    source      = "../base/scripts/versions.ps1"
  }

  provisioner "powershell" {
    scripts = [
      "scripts/configure-cloudwatch-agent.ps1",
      "scripts/install-buildkite-agent.ps1",
      "scripts/install-s3secrets-helper.ps1"
    ]
  }

  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ami-create-win-sysprep.html
  provisioner "powershell" {
    inline = [
      "Remove-Item -Path C:/packer-temp -Recurse",
      "& 'C:/Program Files/Amazon/EC2Launch/EC2Launch.exe' sysprep --shutdown true --clean true"
    ]
  }
}
