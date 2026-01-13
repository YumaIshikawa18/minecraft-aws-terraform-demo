terraform {
  backend "s3" {
    bucket = "yuma-minecraft-tfstate"
    key    = "minecraft/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
