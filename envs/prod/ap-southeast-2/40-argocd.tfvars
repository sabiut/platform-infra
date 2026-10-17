environment               = "prod"
region                    = "ap-southeast-2"
argocd_chart_version      = "10.10.3" # Argo CD v3.5.5
argocd_apps_chart_version = "2.0.6"
gitops_repo_url           = "https://gitlab.com/sabiut/gitops.git"

# The gitops repo is public, so Argo CD needs no credentials. For a private repo, set this to
# a Secrets Manager secret holding a GitLab deploy token (default: platform/gitops-repo).
gitops_repo_secret_name = ""
