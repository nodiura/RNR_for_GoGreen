terraform {
  cloud {

    organization = "Guild_of_Cloud"

    workspaces {
      name = "GOGREEN"
    }
  }
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.69.0"
    }
  }
}
provider "aws" {
  region = "us-west-1"
}
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}