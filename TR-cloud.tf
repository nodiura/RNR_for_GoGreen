terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  cloud {
    organization = "Guild_of_Cloud"
    workspaces {
      name = "GOGREEN"
    }
  }
}
# Configure the AWS Provider
provider "aws" {
  region = "us-west-1"
}