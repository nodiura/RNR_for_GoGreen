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

provider "aws" {
  region     = "us-west-1"
}
#   access_key = "AKIA3FLDXWVNRDSMWNUH"
#   secret_key = "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"
# }