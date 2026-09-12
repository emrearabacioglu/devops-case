terraform {
  backend "s3" {
    bucket  = "emrearabacioglu-devops-tfstate"
    key     = "eks-cluster/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}