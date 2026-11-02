# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A CONSUL CLUSTER IN AWS
# These templates show an example of how to use the consul-cluster module to deploy Consul in AWS. We deploy two Auto
# Scaling Groups (ASGs): one with a small number of Consul server nodes and one with a larger number of Consul client
# nodes. Note that these templates assume that the AMI you provide via the ami_id input variable is built from
# the examples/consul-ami/consul.json Packer template.
# ---------------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# ----------------------------------------------------------------------------------------------------------------------
terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.14.0 as the minimum version, as that version added support for validation and the alltrue function
  # Removing the validation completely will yield a version compatible with 0.12.26 as that added support for
  # required_providers with source URLs
  required_version = ">= 0.14.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# AUTOMATICALLY LOOK UP THE LATEST AMI BUILT FROM /examples/consul-ami
# The data source below looks up the most recent AMI built from that Packer template in this AWS account, so that a
# simple "terraform apply" works without having to fill in ami_id by hand.
#
# NOTE: This Terraform data source must return at least one AMI result or the entire template will fail, so build the
# Packer template at least once in this account before running "terraform apply" without setting ami_id.
# ---------------------------------------------------------------------------------------------------------------------
data "aws_ami" "consul" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "name"
    values = ["consul-amazon-linux-2023-*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL SERVER NODES
# ---------------------------------------------------------------------------------------------------------------------

module "consul_servers" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:hashicorp/terraform-aws-consul.git//modules/consul-cluster?ref=v0.0.1"
  source = "./modules/consul-cluster"

  cluster_name  = "${var.cluster_name}-server"
  cluster_size  = var.num_servers
  instance_type = "t2.micro"
  spot_price    = var.spot_price

  # The EC2 Instances will use these tags to automatically discover each other and form a cluster
  cluster_tag_key   = var.cluster_tag_key
  cluster_tag_value = var.cluster_name

  ami_id = var.ami_id == null ? data.aws_ami.consul.image_id : var.ami_id
  user_data = templatefile("${path.module}/examples/root-example/user-data-server.sh", {
    cluster_tag_key   = var.cluster_tag_key
    cluster_tag_value = var.cluster_name
  })

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnet_ids.default.ids

  # If set to true, this allows access to the consul HTTPS API
  enable_https_port = var.enable_https_port

  # To make testing easier, we allow Consul and SSH requests from any IP address here but in a production
  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  allowed_ssh_cidr_blocks = ["0.0.0.0/0"]

  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  ssh_key_name                = var.ssh_key_name

  tags = [
    {
      key                 = "Environment"
      value               = "development"
      propagate_at_launch = true
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL CLIENT NODES
# Note that you do not have to use the consul-cluster module to deploy your clients. We do so simply because it
# provides a convenient way to deploy an Auto Scaling Group with the necessary IAM and security group permissions for
# Consul, but feel free to deploy those clients however you choose (e.g. a single EC2 Instance, a Docker cluster, etc).
# ---------------------------------------------------------------------------------------------------------------------

module "consul_clients" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:hashicorp/terraform-aws-consul.git//modules/consul-cluster?ref=v0.0.1"
  source = "./modules/consul-cluster"

  cluster_name  = "${var.cluster_name}-client"
  cluster_size  = var.num_clients
  instance_type = "t2.micro"
  spot_price    = var.spot_price

  cluster_tag_key   = "consul-clients"
  cluster_tag_value = var.cluster_name

  ami_id = var.ami_id == null ? data.aws_ami.consul.image_id : var.ami_id
  user_data = templatefile("${path.module}/examples/root-example/user-data-client.sh", {
    cluster_tag_key   = var.cluster_tag_key
    cluster_tag_value = var.cluster_name
  })

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnet_ids.default.ids

  # To make testing easier, we allow Consul and SSH requests from any IP address here but in a production
  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  allowed_ssh_cidr_blocks = ["0.0.0.0/0"]

  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  ssh_key_name                = var.ssh_key_name
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY CONSUL IN THE DEFAULT VPC AND SUBNETS
# Using the default VPC and subnets makes this example easy to run and test, but it means Consul is accessible from the
# public Internet. For a production deployment, we strongly recommend deploying into a custom VPC with private subnets.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = var.vpc_id == null ? true : false
  id      = var.vpc_id
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_region" "current" {
}
