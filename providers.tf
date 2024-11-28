terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.78.0"
    }
  }
}

provider "aws" {
  region ="ap-south-1"
  aws_access_key_id = "AKIAQ4J5YC6OMHVU3B6G"
  aws_secret_access_key = "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"
}
