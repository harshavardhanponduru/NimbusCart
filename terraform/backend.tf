terraform {
  backend "s3" {
    bucket         = "nimbuscart-tf-state-bucket-yourid" # Replace with your unique S3 bucket name
    key            = "nimbuscart/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "nimbuscart-tf-locks"
    encrypt        = true
  }
}