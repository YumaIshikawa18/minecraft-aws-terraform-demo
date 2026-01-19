module "oidc_github" {
  source = "../modules/oidc_github"
}

module "tfstate" {
  source = "../modules/s3_tfstate"

  tfstate_bucket_name = var.tfstate_bucket_name
}

module "gha_role" {
  source = "../modules/iam_gha_role"

  gha_role_name     = var.gha_role_name
  oidc_provider_arn = module.oidc_github.provider_arn
  github_owner      = var.github_owner
  github_repo       = var.github_repo
}
