provider "aws" {
  region = var.aws_region

  access_key = "mock-access-key"
  secret_key = "mock-secret-key"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}
