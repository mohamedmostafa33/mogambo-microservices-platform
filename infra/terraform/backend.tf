terraform {
  backend "s3" {
    bucket         = "mogambo-tfstate"
    key            = "terraform.tfstate"
    region         = "us-east-1"

    dynamodb_table = "mogambo-tfstate-lock"
    encrypt        = true
  }
}