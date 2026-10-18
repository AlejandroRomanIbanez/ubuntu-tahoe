terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 5.0" }
    tls   = { source = "hashicorp/tls", version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ssm_parameter" "noble" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_ami" "selected" {
  owners = ["099720109477"] # Canonical
  filter {
    name   = "image-id"
    values = [var.ami_id != "" ? var.ami_id : nonsensitive(data.aws_ssm_parameter.noble.value)]
  }
}

resource "tls_private_key" "test" {
  count     = var.key_name == "" ? 1 : 0
  algorithm = "ED25519"
}

resource "aws_key_pair" "test" {
  count      = var.key_name == "" ? 1 : 0
  key_name   = "ubuntu-tahoe-test-${var.name_suffix}"
  public_key = tls_private_key.test[0].public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  count           = var.key_name == "" ? 1 : 0
  content         = tls_private_key.test[0].private_key_openssh
  filename        = "${path.module}/ubuntu-tahoe-test.pem"
  file_permission = "0600"
}

locals {
  key_name = var.key_name != "" ? var.key_name : aws_key_pair.test[0].key_name
  key_path = var.key_name != "" ? "<your-key>.pem" : "${path.module}/ubuntu-tahoe-test.pem"
}

resource "aws_security_group" "desktop_test" {
  name        = "ubuntu-tahoe-test-${var.name_suffix}"
  description = "Restricted SSH access for disposable Ubuntu Tahoe testing"
  ingress {
    description = "SSH from trusted CIDR only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Project = "ubuntu-tahoe", Purpose = "disposable-desktop-test" }
}

resource "aws_instance" "desktop_test" {
  ami                         = data.aws_ami.selected.id
  instance_type               = var.instance_type
  key_name                    = local.key_name
  vpc_security_group_ids      = [aws_security_group.desktop_test.id]
  associate_public_ip_address = true
  user_data                   = file("${path.module}/../bootstrap/desktop.sh")
  root_block_device {
    volume_size           = 40
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  metadata_options {
    http_tokens = "required"
  }
  tags = { Name = "ubuntu-tahoe-test", Project = "ubuntu-tahoe", AutoShutdownReminder = "true" }
}
