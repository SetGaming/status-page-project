variable "bastion_allowed_cidrs" {
  description = "Public CIDRs allowed to SSH to the Bastion"
  type        = list(string)
  default = [
    "77.126.130.161/32",
    "188.191.230.13/32"
  ]
}

variable "eks_public_access_cidrs" {
  description = "Public CIDRs allowed to reach the EKS API endpoint"
  type        = list(string)
  default = [
    "77.126.130.161/32",
    "188.191.230.13/32"
  ]
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
  default     = 3
}

variable "eks_min_nodes" {
  description = "Minimum EKS worker node count"
  type        = number
  default     = 1
}

variable "eks_max_nodes" {
  description = "Maximum EKS worker node count"
  type        = number
  default     = 3
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


variable "ubuntu_ami_id" {
  description = "Pinned Ubuntu AMI for Bastion and Jenkins"
  type        = string
  default     = "ami-0d7f022123f8ff19d"
}
