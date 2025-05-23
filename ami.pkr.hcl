packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  tags = {
    Name    = "packer"
    Team    = "shared"
    Billing = "shared"
  }

  spot_instance_types = [
    "t3a.small",
    "t3.small",
    "t2.small",
    "t2.medium",
    "t3.medium",
    "t3a.medium"
  ]

  ami_users = [
  "121985214683"  
  ]

  ami_regions = [
    "us-west-1"
  ]
}

source "amazon-ebs" "amazon-linux-2023" {
  region = "us-west-1"
                            
  ami_name                = "plivo/al2023-ami-2023.{{timestamp}}-{{uuid}}-x86_64"
  ami_description         = "Plivo Golden AMI"
  ami_virtualization_type = "hvm"

  spot_price          = "auto"
  spot_instance_types = local.spot_instance_types

  ebs_optimized = true

  communicator  = "ssh"
  ssh_username  = "ec2-user"
  ssh_timeout   = "10m"
  ssh_interface = "private_ip"

  run_volume_tags = local.tags
  run_tags        = local.tags
  fleet_tags      = local.tags
  spot_tags       = local.tags

  ami_users   = local.ami_users
  ami_regions = local.ami_regions

  tags = {
    BuildRegion   = "{{ .BuildRegion }}"
    SourceAMI     = "{{ .SourceAMI }}"
    SourceAMIName = "{{ .SourceAMIName }}"
    Team          = "shared"
    Billing       = "shared"
  }

  source_ami_filter {
    most_recent = true

    owners = [
      "amazon"
    ]

    filters = {
      virtualization-type = "hvm"
      name                = "al2023-ami-2023.*-x86_64"
      root-device-type    = "ebs"
    }
  }

  security_group_filter {
    filters = {
      "tag:Name" : "ec2-ssh-private"
    }
  }

  subnet_filter {
    random = true

    filters = {
      "tag:SubnetType" : "private"
      "tag:Team" : "shared"
    }
  }
}

build {
  sources = [
    "source.amazon-ebs.amazon-linux-2023"
  ]

  provisioner "ansible" {
    playbook_file        = "./playbook.yml"
    galaxy_file          = "./roles/requirements.yml"
    galaxy_force_install = true
    user                 = "ec2-user"
  }

  post-processor "manifest" {}
}
