variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "ami_id" {
  type        = string
  default     = ""
  description = "Ubuntu 24.04 LTS AMI ID. Empty = Canonical's current Noble image from the public SSM parameter (owner 099720109477 is verified)."
}

variable "instance_type" {
  type        = string
  default     = "t3.xlarge"
  description = "At least 2 vCPUs and 8 GiB RAM; GNOME runs on llvmpipe without a GPU."
}

variable "key_name" {
  type        = string
  default     = ""
  description = "Existing EC2 key pair name. Empty = generate a disposable key written to ./ubuntu-tahoe-test.pem (gitignored)."
}

variable "trusted_cidr" {
  type        = string
  description = "Trusted source CIDR for SSH, ideally a single address with /32. 0.0.0.0/0 is rejected."
  validation {
    condition     = can(cidrhost(var.trusted_cidr, 0)) && var.trusted_cidr != "0.0.0.0/0"
    error_message = "trusted_cidr must be a valid CIDR and must not be 0.0.0.0/0."
  }
}

variable "name_suffix" {
  type    = string
  default = "alpha"
}
