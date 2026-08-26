# Status Page Project

DevOps final project for deploying Status Page on AWS using Infrastructure as Code, containers, Kubernetes and CI/CD.

## Stack

- AWS
- Terraform
- Amazon EKS
- Amazon ECR
- Amazon RDS PostgreSQL
- Jenkins
- Ansible
- Docker
- Kubernetes
- Helm
- Trivy
- Prometheus
- Grafana
- Loki
- Grafana Alloy
- Alertmanager

## Repository Structure

status-page-project/
├── terraform/
├── ansible/
├── jenkins/
├── helm/
├── docs/
├── .gitignore
└── README.md

## Infrastructure

Infrastructure is managed using Terraform.

The initial networking layer contains:

- VPC
- 2 Public Subnets
- 2 Private Subnets
- Internet Gateway
- Public Route Table
- Private Route Table

Additional infrastructure will be added gradually after validation and cost review.
