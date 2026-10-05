
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.3.0"
    }
  }
  
  required_version = ">= 1.2"
}



provider "aws" {
  region = "us-east-1"  #Region where the resources will be created
}
