primary_region = "ap-southeast-2"
replica_region = "eu-west-2"
github_repo    = "sabiut/platform-infra"
# GitHub sends immutable OIDC subjects for this repo (owner and repo IDs included).
github_sub_prefix = "repo:sabiut@8152759/platform-infra@1422767561"
gitlab_namespace  = "sabiut"
gitlab_app_repos = {
  backend  = "backend"
  frontend = "frontend"
}
domain = "" # no domain yet
