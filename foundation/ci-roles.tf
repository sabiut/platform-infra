# GitHub Actions (platform-infra) and GitLab CI (backend, frontend) sign in with OIDC.
# Nothing stores AWS keys.

# ---- GitHub Actions ----

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "gha_plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Pull requests, plus scheduled drift checks on main.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.github_sub}:pull_request",
        "${local.github_sub}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "gha_plan" {
  name               = "gha-plan"
  assume_role_policy = data.aws_iam_policy_document.gha_plan_trust.json
}

resource "aws_iam_role_policy_attachment" "gha_plan_readonly" {
  role       = aws_iam_role.gha_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ReadOnlyAccess can't write lock files or read the one secret the argocd stack needs at plan time.
data "aws_iam_policy_document" "gha_plan_extra" {
  statement {
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*.tflock"]
  }
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:*:${local.account_id}:secret:platform/gitops-repo-*"]
  }
}

resource "aws_iam_role_policy" "gha_plan_extra" {
  role   = aws_iam_role.gha_plan.id
  policy = data.aws_iam_policy_document.gha_plan_extra.json
}

data "aws_iam_policy_document" "gha_apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Only jobs running in the protected "production" environment, which requires a reviewer.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.github_sub}:environment:production"]
    }
  }
}

resource "aws_iam_role" "gha_apply" {
  name               = "gha-apply"
  assume_role_policy = data.aws_iam_policy_document.gha_apply_trust.json
  # A region build (EKS, then RDS) can outlast the default 1-hour session; the workflows ask
  # for 2 hours (role-duration-seconds: 7200).
  max_session_duration = 7200
}

# Broad on purpose: this role creates VPCs, clusters and IAM roles. The guard is the trust
# policy above (main branch, approved environment), not the permissions.
resource "aws_iam_role_policy_attachment" "gha_apply_admin" {
  role       = aws_iam_role.gha_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ---- GitLab CI (backend, frontend) ----

resource "aws_iam_openid_connect_provider" "gitlab" {
  url            = "https://gitlab.com"
  client_id_list = ["https://gitlab.com"]
}

data "aws_iam_policy_document" "gitlab_push_trust" {
  for_each = var.gitlab_app_repos
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.gitlab.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "gitlab.com:aud"
      values   = ["https://gitlab.com"]
    }
    # Only the main branch of this one project can push images.
    condition {
      test     = "StringEquals"
      variable = "gitlab.com:sub"
      values   = ["project_path:${var.gitlab_namespace}/${each.key}:ref_type:branch:ref:main"]
    }
  }
}

data "aws_iam_policy_document" "gitlab_push" {
  for_each = var.gitlab_app_repos
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart",
    ]
    resources = ["arn:aws:ecr:${var.primary_region}:${local.account_id}:repository/${each.value}"]
  }
}

resource "aws_iam_role" "gitlab_push" {
  for_each           = var.gitlab_app_repos
  name               = "gitlab-${each.key}-push"
  assume_role_policy = data.aws_iam_policy_document.gitlab_push_trust[each.key].json
}

resource "aws_iam_role_policy" "gitlab_push" {
  for_each = var.gitlab_app_repos
  role     = aws_iam_role.gitlab_push[each.key].id
  policy   = data.aws_iam_policy_document.gitlab_push[each.key].json
}
