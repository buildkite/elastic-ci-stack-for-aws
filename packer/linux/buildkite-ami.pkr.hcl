variable "arch" {
  type    = string
  default = "x86_64"
}

variable "goarch" {
  type    = string
  default = "amd64"
}

variable "instance_type" {
  type    = string
  default = "m5.xlarge"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

data "amazon-ami" "amazon_linux_2" {
  filters = {
    architecture        = "${var.arch}"
    name                = "amzn2-ami-kernel-5.10-hvm-2.0.*-gp2"
    virtualization-type = "hvm"
  }

  most_recent = true
  owners      = ["amazon"]
  region      = "${var.region}"
}

source "amazon-ebs" "elastic_stack" {
  source_ami = "${data.amazon-ami.amazon_linux_2.id}"

  ami_name        = "buildkite-stack-linux-${var.arch}-${replace(timestamp(), ":", "-")}"
  ami_description = "Buildkite Elastic Stack (Amazon Linux 2 LTS w/ docker)"
  ami_groups      = ["all"]

  instance_type = "${var.instance_type}"
  region        = "${var.region}"

  ssh_username = "ec2-user"
}

build {
  sources = ["source.amazon-ebs.elastic_stack"]

  provisioner "file" {
    destination = "/tmp"
    source      = "conf"
  }

  provisioner "file" {
    destination = "/tmp/plugins"
    source      = "../../plugins"
  }

  provisioner "shell" {
    script = "scripts/install-utils.sh"
  }

  provisioner "shell" {
    script = "scripts/install-cloudwatch-agent.sh"
  }

  provisioner "shell" {
    script = "scripts/install-lifecycled.sh"
  }

  provisioner "shell" {
    script = "scripts/install-docker.sh"
  }

  provisioner "shell" {
    script = "scripts/install-buildkite-agent.sh"
  }

  provisioner "shell" {
    script = "scripts/install-s3secrets-helper.sh"
  }

  provisioner "shell" {
    script = "scripts/install-git-lfs.sh"
  }

  provisioner "shell" {
    script = "scripts/install-session-manager-plugin.sh"
  }

  provisioner "shell" {
    script = "scripts/install-nvme-cli.sh"
  }

  provisioner "shell" {
    inline = ["rm /home/ec2-user/.ssh/authorized_keys"]
  }
}
