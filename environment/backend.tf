terraform {
  backend "s3" {
    bucket = "YOUR_TFSTATE_BUCKET_NAME"
    key    = "minecraft/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
