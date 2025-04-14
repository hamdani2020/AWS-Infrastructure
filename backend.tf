terraform {
  backend "s3" {
    bucket         = "terra-state-bucket-123"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-lock"
    use_lockfile   = true
  }
}
