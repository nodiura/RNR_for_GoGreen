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
      name = "GoGreen2"
    }
  }
}

provider "aws" {
  region     = "us-west-1"
}
