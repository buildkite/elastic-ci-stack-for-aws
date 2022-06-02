variable "region" {
  type    = string
  default = "us-east-1"
}

data "amazon-ami" "windows_server_2019" {
  filters = {
    name                = "Windows_Server-2019-English-Full-Containers*"
    virtualization-type = "hvm"
  }

  most_recent = true
  owners      = ["amazon"]
  region      = "${var.region}"
}

source "amazon-ebs" "elastic_stack_windows" {
  source_ami = "${data.amazon-ami.windows_server_2019.id}"

  ami_name        = "buildkite-stack-windows-${replace(timestamp(), ":", "-")}"
  ami_description = "Buildkite Elastic Stack (Windows Server 2019 w/ docker)"
  ami_groups      = ["all"]

  instance_type = "m5.xlarge"
  region        = "${var.region}"

  communicator   = "winrm"
  winrm_insecure = true
  winrm_use_ssl  = true
  winrm_username = "Administrator"

  user_data_file = "scripts/ec2-userdata.ps1"
}

build {
  sources = ["source.amazon-ebs.elastic_stack_windows"]

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
    inline = ["C:/ProgramData/Amazon/EC2-Windows/Launch/Scripts/InitializeInstance.ps1 -Schedule", "C:/ProgramData/Amazon/EC2-Windows/Launch/Scripts/SysprepInstance.ps1 -NoShutdown"]
  }

}
