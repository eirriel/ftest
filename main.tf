provider "aws" {
  version = "~> 2.8"
  region = "ap-southeast-2"
}

locals {
  user_data_master = <<EOF
echo "I'm a master"
EOF
  user_data_node   = <<EOF
echo "I'm a node"
EOF
  vpc_cidr         = "10.8.0.0/16"
  //  mgmt_cidr        = ["0.0.0.0/0",local.vpc_cidr] open any source
  mgmt_cidr = ["0.0.0.0/0", local.vpc_cidr]
}

// Create a VPC

module "vpc" {
  source        = "./modules/vpc"
  vpc_cidr      = local.vpc_cidr
  subneta_cidr  = "10.8.1.0/24"
  subnetz_cidr  = "10.8.2.0/24"
  subnetpa_cidr = "10.8.3.0/24"
  subnetpz_cidr = "10.8.4.0/24"
}


data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

// SG for SSH connections
resource "aws_security_group" "sg_ssh" {
  name        = "security_group_ssh"
  description = "Security group for ssh access"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group" "sg_mgmt" {
  name        = "security_group_mgmt"
  description = "Security group for mgmt access"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "allow_ssh" {
  cidr_blocks       = local.mgmt_cidr
  from_port         = 22
  protocol          = "TCP"
  to_port           = 22
  type              = "ingress"
  security_group_id = aws_security_group.sg_mgmt.id
}

resource "aws_security_group_rule" "outbound_all" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "-1"
  to_port           = 0
  type              = "egress"
  security_group_id = aws_security_group.sg_mgmt.id
}

// SG for master connections

resource "aws_security_group" "security_group_master" {
  name        = "security_group_master"
  description = "Security group for k8s_master"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "sg_k8s_master" {
  cidr_blocks       = local.mgmt_cidr
  from_port         = 6443
  protocol          = "TCP"
  to_port           = 6443
  type              = "ingress"
  security_group_id = aws_security_group.security_group_master.id
}

// SG for node connections

resource "aws_security_group" "security_group_node" {
  name        = "security_group_node"
  description = "Security group for k8s_master"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "sg_k8s_node" {
  cidr_blocks       = [local.vpc_cidr]
  from_port         = 443
  protocol          = "TCP"
  to_port           = 443
  type              = "ingress"
  security_group_id = aws_security_group.security_group_node.id
}

// Cluster instances

resource "aws_key_pair" "test" {
  key_name   = "test"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDqBLaEjYbHNuLPcUCYSDC+rHZuQPXyXWD+hZu55jjx2zVxfrT9hNUYoNS6GvZPJD7qzWVNlXN3WtO5IxCEpG4WHFGzZuiD8wru7WeioSra7xovljvC2WLU8bG27fterR+/HHSOmwyfpflfimnysqC87FK02EBye/V7GD0xMQAPXl1SSRuAyXq91hKP7dHaIMPsuHp+elSppN8viaisWc5sOyj7dQLiWghcsvH/Vw5uplMlJNmXx6OfArbVSn7AyyZYqIWi3e5iR47kR3x67/0nZcXaZEq+jiHWpQ/n1k9AI+RSVaqV3Be4Gzy5FjF25i02AqQs/2ZvvXL/xh4kOT81 aeusebi@TMMAC001374"
}


resource "aws_instance" "k8s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3a.small"
  subnet_id              = module.vpc.subnet_a_id
  vpc_security_group_ids = [aws_security_group.sg_mgmt.id, aws_security_group.security_group_master.id]
  user_data_base64       = base64encode(local.user_data_master)
  key_name               = aws_key_pair.test.key_name
  tags = {
    Name = "k8s_master"
  }
  provisioner "local-exec" {
    command = <<EOT
    sleep 40;
    export ANSIBLE_HOST_KEY_CHECKING=False;
    ansible-playbook -u ubuntu -i "${aws_instance.k8s_master.public_ip}," ansible-master.yml -e "node_ip=${aws_instance.k8s_master.private_ip} pod_cidr='172.32.0.0/24'"
    EOT
  }
}

resource "aws_instance" "k8s_node1" {
  depends_on             = [aws_instance.k8s_master]
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3a.small"
  subnet_id              = module.vpc.private_subnet_a_id
  vpc_security_group_ids = [aws_security_group.sg_mgmt.id, aws_security_group.security_group_node.id]
  user_data_base64       = base64encode(local.user_data_node)
  key_name               = aws_key_pair.test.key_name
  tags = {
    Name = "k8s_node1"
  }
  provisioner "local-exec" {
    command = <<EOT
    sleep 20;
    export ANSIBLE_HOST_KEY_CHECKING=False;
    ansible-playbook -u ubuntu -i "${aws_instance.k8s_node1.private_ip}," ansible-nodes.yml -e "node_ip=${aws_instance.k8s_node1.private_ip} ansible_ssh_common_args='-o ProxyCommand=\"ssh -W %h:%p -q ubuntu@${aws_instance.k8s_master.public_ip}\"'"
    EOT
  }
}

resource "aws_instance" "k8s_node2" {
  depends_on             = [aws_instance.k8s_master]
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3a.small"
  subnet_id              = module.vpc.private_subnet_z_id
  vpc_security_group_ids = [aws_security_group.sg_mgmt.id, aws_security_group.security_group_node.id]
  user_data_base64       = base64encode(local.user_data_node)
  key_name               = aws_key_pair.test.key_name
  tags = {
    Name = "k8s_node2"
  }
  provisioner "local-exec" {
    command = <<EOT
    sleep 20;
    export ANSIBLE_HOST_KEY_CHECKING=False;
    ansible-playbook -u ubuntu -i "${aws_instance.k8s_node2.private_ip}," ansible-nodes.yml -e "node_ip=${aws_instance.k8s_node2.private_ip} ansible_ssh_common_args='-o ProxyCommand=\"ssh -W %h:%p -q ubuntu@${aws_instance.k8s_master.public_ip}\"'"
    EOT
  }
}

