variable "bastion_allowed_cidr" {
  description = "Public CIDR allowed to SSH to the Bastion"
  type        = string
  default     = "176.229.130.226/32"
}

variable "eks_public_access_cidr" {
  description = "Public CIDR allowed to reach the EKS API endpoint"
  type        = string
  default     = "176.229.130.226/32"
}

variable "ec2_key_name" {
  description = "Existing EC2 key pair used for Bastion and Jenkins"
  type        = string
  default     = "avivnetaproject"
}

variable "bastion_instance_type" {
  description = "Bastion EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "jenkins_instance_type" {
  description = "Jenkins EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "eks_node_instance_type" {
  description = "EKS managed node instance type"
  type        = string
  default     = "t3.medium"
}

variable "eks_desired_nodes" {
  description = "Desired EKS worker node count"
  type        = number
  default     = 2
}

variable "eks_min_nodes" {
  description = "Minimum EKS worker node count"
  type        = number
  default     = 1
}

variable "eks_max_nodes" {
  description = "Maximum EKS worker node count"
  type        = number
  default     = 2
}

variable "rds_instance_class" {
  description = "RDS PostgreSQL instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "owner" {
  description = "Owner tag required by the AWS environment"
  type        = string
  default     = "avivneta"
}
