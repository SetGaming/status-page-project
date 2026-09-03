resource "aws_security_group" "bastion" {
  name_prefix = "avivneta-${var.project_name}-${var.environment}-bastion-"
  description = "Bastion access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from Aviv current public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "avivneta-${var.project_name}-${var.environment}-bastion-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "jenkins" {
  name_prefix = "avivneta-${var.project_name}-${var.environment}-jenkins-"
  description = "Private Jenkins access through Bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description     = "Jenkins UI from Bastion"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description     = "Jenkins UI from Client VPN"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.client_vpn.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "avivneta-${var.project_name}-${var.environment}-jenkins-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "rds" {
  name_prefix = "avivneta-${var.project_name}-${var.environment}-rds-"
  description = "PostgreSQL access from EKS only"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "avivneta-${var.project_name}-${var.environment}-rds-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "eks_api_from_bastion" {
  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.bastion.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  description = "EKS API from Bastion"
}

resource "aws_vpc_security_group_ingress_rule" "eks_api_from_jenkins" {
  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.jenkins.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  description = "EKS API from Jenkins"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_eks" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"

  description = "PostgreSQL from EKS cluster security group"
}
