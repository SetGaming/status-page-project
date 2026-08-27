resource "aws_launch_template" "eks_nodes" {
  name_prefix            = "avivneta-${var.project_name}-${var.environment}-eks-"
  update_default_version = true

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "avivneta-${var.project_name}-${var.environment}-eks-worker"
      Owner       = var.owner
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name        = "avivneta-${var.project_name}-${var.environment}-eks-worker-volume"
      Owner       = var.owner
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }

  tags = {
    Name = "avivneta-${var.project_name}-${var.environment}-eks-launch-template"
  }
}
