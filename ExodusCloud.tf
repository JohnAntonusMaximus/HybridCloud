provider "aws" {
    shared_credentials_file = "[INSERT_PATH_TO_AWS_CREDENTIALS]" # Change this to your credentials path
    region = "us-west-1"
}

module "exodus-prod" {
  source = "terraform-aws-modules/vpc/aws"

  create_vpc = true # Change to create VPC resources conditionally.

  name = "exodus-prod"

  cidr = "10.0.0.0/16"

  azs             = ["us-west-1a", "us-west-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  public_dedicated_network_acl  = true
  private_dedicated_network_acl = true

  assign_generated_ipv6_cidr_block = true
  
  public_inbound_acl_rules     = "${concat(local.network_acls["default_inbound"], local.network_acls["public_inbound"])}"
  public_outbound_acl_rules    = "${concat(local.network_acls["default_outbound"], local.network_acls["public_outbound"])}"

  enable_nat_gateway      = true
  single_nat_gateway      = false
  one_nat_gateway_per_az  = true
  reuse_nat_ips           = true
  external_nat_ip_ids = ["${aws_eip.nat.*.id}"]

  public_subnet_tags = {
    Name = "exodus-prod-public"
  }

  private_subnet_tags = {
    Name = "exodus-prod-private"
  }

  tags = {
    Owner       = "ExodusDevOps"
    Environment = "prod"
  }

  vpc_tags = {
    Name = "exodus-prod"
  }
}

locals {
  network_acls = {
    default_inbound = [
      {
        rule_number = 900
        rule_action = "allow"
        from_port   = 1024
        to_port     = 65535
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
    ]

    default_outbound = [
      {
        rule_number = 900
        rule_action = "allow"
        from_port   = 32768
        to_port     = 65535
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
    ]

    public_inbound = [
      {
        rule_number = 100
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 110
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 120
        rule_action = "allow"
        from_port   = 3000
        to_port     = 3000
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 130
        rule_action = "allow"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0" # This wouldn't be used in production, would use a VPN or a static IP range, just for ease of bootstrapping the demo
      },
    ]

    public_outbound = [
      {
        rule_number = 100
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 110
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 120
        rule_action = "allow"
        from_port   = 3000
        to_port     = 3000
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 130
        rule_action = "allow"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_block  = "10.0.100.0/22"
      },
    ]
  }
}

# Prevent release of Elastic IPs on NAT Gateways if Terraform is destroyed for whatever reason
resource "aws_eip" "nat" {
  count = 2
  vpc = true
}

resource "aws_security_group" "sgexodus" {
  name = "sgexodus"
  description = "Allow incoming HTTP connections & SSH access"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks =  ["0.0.0.0/0"]
  }

  egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id="${module.exodus-prod.vpc_id}"

  tags {
    Name = "exodus-prod"
  }
}


 // Create an EC2 instance, bootstrap it with an application, SG, and subnetting
resource "aws_instance" "node-weather" {
     count = 1
     ami = "${var.amazon-linux}"
     instance_type = "t2.micro"
     key_name = "${var.ssh_key}" # Create a ssh-key in AWS console and put value of key-pair in variables.auto.tfvars
     subnet_id = "${module.exodus-prod.public_subnets[0]}"
     security_groups = ["${aws_security_group.sgexodus.id}"]
     tags {
         Name = "exodus-prod"
     }

     provisioner "remote-exec" {

         connection {
             user = "ec2-user"
             type = "ssh"
             private_key = "${file("[INSERT_PATH_TO_PEM_FILE]")}" 
         }

         inline = [
             "sudo yum update -y",
             "curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.32.0/install.sh | bash",
             ". ~/.nvm/nvm.sh",
             "nvm install 8.11.1",
             "sudo yum install -y git",
             "git clone https://github.com/JohnAntonusMaximus/node-weather.git",
             "cd node-weather",
             "npm install",
             "sleep 1",
             "nohup npm start &",
             "sleep 1"
    ]
     }
 }
