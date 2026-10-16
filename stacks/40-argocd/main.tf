# Argo CD itself, installed once. From here on Argo CD manages everything in the cluster,
# reading envs/<environment>/<region>/apps/ in the gitops repo.

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  wait             = true
  timeout          = 900

  values = [file("${path.module}/values/argocd.yaml")]
}

# GitLab deploy token for the gitops repo. Read as an ephemeral value and written with a
# write-only attribute, so the token never lands in Terraform state.
ephemeral "aws_secretsmanager_secret_version" "gitops_repo" {
  count     = local.plan_only ? 0 : 1
  secret_id = var.gitops_repo_secret_name
}

locals {
  gitops_creds = try(jsondecode(ephemeral.aws_secretsmanager_secret_version.gitops_repo[0].secret_string),
  { username = "PLANONLY", password = "PLANONLY" })
}

resource "kubernetes_secret_v1" "gitops_repo" {
  metadata {
    name      = "repo-gitops"
    namespace = "argocd"
    labels    = { "argocd.argoproj.io/secret-type" = "repository" }
  }
  # data and data_wo can't be combined, so the non-secret fields are write-only too.
  data_wo = {
    type     = "git"
    url      = var.gitops_repo_url
    username = local.gitops_creds.username
    password = local.gitops_creds.password
  }
  data_wo_revision = var.gitops_repo_token_version

  depends_on = [helm_release.argocd]
}

# The one Application Terraform creates (app of apps). Everything else comes from Git.
resource "helm_release" "root_app" {
  name       = "argocd-root"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version

  values = [yamlencode({
    applications = {
      root = {
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = var.gitops_repo_url
          targetRevision = "main"
          path           = "envs/${var.environment}/${var.region}/apps"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = { prune = true, selfHeal = true }
        }
      }
    }
  })]

  depends_on = [kubernetes_secret_v1.gitops_repo]
}
