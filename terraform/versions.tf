terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "3.2.0"
    }

    http = {
      source  = "hashicorp/http"
      version = ">= 3.5.0"
    }
  }
}
