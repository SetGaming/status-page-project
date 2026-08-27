terraform {
  backend "s3" {
    bucket       = "status-page-terraform-state-992382545251"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
