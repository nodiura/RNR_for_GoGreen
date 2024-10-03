terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.69.0"
    }
  }
  cloud {
    organization = "Guild_of_Cloud"
    workspaces {
      name = "GOGREEN"
    }
  }
}
provider "aws" {
  region = "us-west-1"
}