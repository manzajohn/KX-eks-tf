locals {
  ami           = "ami-0f19d220602031aed" # Amazon Linux 2 AMI
  instance_type = "t3.small"
  key_name      = "bastion-kp"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "bastion"
  role = var.role_name
}

resource "tls_private_key" "tls_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2key" {
  key_name   = var.public_key_name
  public_key = tls_private_key.tls_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.tls_key.private_key_pem
  filename        = var.filename
  file_permission = "0600"
}

resource "aws_instance" "bastion" {
  ami           = local.ami
  instance_type = local.instance_type

  # key_name                    = local.key_name
  key_name                    = aws_key_pair.ec2key.key_name
  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[0].id
  iam_instance_profile        = aws_iam_instance_profile.bastion.name

  security_groups = [aws_security_group.bastion-sg.id]

  tags = {
    Name = "K8s Bastion"
  }

  lifecycle {
    ignore_changes = all
  }

  user_data = <<EOF
      #! /bin/bash

      # Install Kubectl
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
      kubectl version --client

      # Install Helm
      curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
      chmod 700 get_helm.sh
      ./get_helm.sh
      helm version

      # Install AWS
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
      unzip awscliv2.zip
      ./aws/install
      aws --version

      # Install aws-iam-authenticator
      curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/aws-iam-authenticator
      chmod +x ./aws-iam-authenticator
      mkdir -p $HOME/bin && cp ./aws-iam-authenticator $HOME/bin/aws-iam-authenticator && export PATH=$PATH:$HOME/bin
      echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
      aws-iam-authenticator help

      # Add the kube config file 
      mkdir ~/.kube
      echo "${module.eks.kubeconfig}" >> ~/.kube/config
  EOF
}

resource "aws_security_group" "bastion-sg" {
  name   = "bastion-sg"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group_rule" "sg-rule-ssh" {
  security_group_id = aws_security_group.bastion-sg.id
  from_port         = 22
  protocol          = "tcp"
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = var.company_vpn_ips
  depends_on        = [aws_security_group.bastion-sg]
}

resource "aws_security_group_rule" "sg-rule-egress" {
  security_group_id = aws_security_group.bastion-sg.id
  type              = "egress"
  from_port         = 0
  protocol          = "all"
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  depends_on        = [aws_security_group.bastion-sg]
}
