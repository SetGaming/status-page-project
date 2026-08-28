resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = {
    Name = "avivneta-${var.project_name}-${var.environment}-bastion-eip"
  }
}

resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}
