resource "aws_instance" "bastion" {
  ami                         = var.ubuntu_ami_id
  instance_type               = var.bastion_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = var.ec2_key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  disable_api_termination     = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 10
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "avivneta-${var.project_name}-${var.environment}-bastion"
  }
}

resource "aws_instance" "jenkins" {
  ami                         = var.ubuntu_ami_id
  instance_type               = var.jenkins_instance_type
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  key_name                    = var.ec2_key_name
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  disable_api_termination     = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [aws_route.private_internet]

  tags = {
    Name = "avivneta-${var.project_name}-${var.environment}-jenkins"
  }
}
