data "aws_caller_identity" "current" {}

locals {
  name       = "${var.environment}-${var.region}"
  account_id = data.aws_caller_identity.current.account_id
  # Short region code for IAM names, which are limited to 38 characters as a prefix:
  # ap-southeast-2 -> apse2, eu-west-2 -> euw2, us-east-1 -> use1.
  short_region = replace(replace(replace(replace(replace(replace(replace(var.region,
  "southeast", "se"), "northeast", "ne"), "central", "c"), "south", "s"), "north", "n"), "west", "w"), "east", "e")
  iam_prefix = "${var.environment}-${replace(local.short_region, "-", "")}"

  access_entries = merge(
    {
      for arn in concat(var.admin_principal_arns, ["arn:aws:iam::${local.account_id}:role/gha-apply"]) :
      "admin-${md5(arn)}" => {
        principal_arn = arn
        policy_associations = {
          admin = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    },
    {
      for arn in var.viewer_principal_arns :
      "view-${md5(arn)}" => {
        principal_arn = arn
        policy_associations = {
          view = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    }
  )
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.28"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  vpc_id     = local.network.vpc_id
  subnet_ids = local.network.private_subnet_ids

  endpoint_private_access      = true
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.public_access_cidrs

  # Access entries instead of the aws-auth ConfigMap; nobody gets admin just for creating it.
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false
  access_entries                           = local.access_entries

  # Kubernetes Secrets are envelope-encrypted with a KMS key the module creates.
  encryption_config = { resources = ["secrets"] }

  enabled_log_types                      = ["api", "audit", "authenticator"]
  cloudwatch_log_group_retention_in_days = 30

  addons = {
    vpc-cni = {
      before_compute       = true
      configuration_values = jsonencode({ enableNetworkPolicy = "true" })
    }
    eks-pod-identity-agent = { before_compute = true }
    kube-proxy             = {}
    coredns                = {}
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = module.pod_identity["ebs-csi"].iam_role_arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      # IMDSv2 only, and hop limit 1 so pods can't borrow the node's IAM role.
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }

      labels = { role = "general" }
      # Cluster Autoscaler finds node groups by these tags.
      tags = {
        "k8s.io/cluster-autoscaler/enabled"       = "true"
        "k8s.io/cluster-autoscaler/${local.name}" = "owned"
      }
    }
  }
}

# One IAM role per add-on ServiceAccount, through EKS Pod Identity.
locals {
  pod_identities = {
    "ebs-csi" = {
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
      policy          = { attach_aws_ebs_csi_policy = true }
    }
    "aws-lb-controller" = {
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
      policy          = { attach_aws_lb_controller_policy = true }
    }
    "cluster-autoscaler" = {
      namespace       = "kube-system"
      service_account = "cluster-autoscaler"
      policy          = { attach_cluster_autoscaler_policy = true }
    }
    "external-secrets" = {
      namespace       = "external-secrets"
      service_account = "external-secrets"
      policy          = { attach_external_secrets_policy = true }
    }
  }
}

module "pod_identity" {
  source   = "terraform-aws-modules/eks-pod-identity/aws"
  version  = "~> 2.8"
  for_each = local.pod_identities

  name = "${local.iam_prefix}-${each.key}"

  attach_aws_ebs_csi_policy        = lookup(each.value.policy, "attach_aws_ebs_csi_policy", false)
  attach_aws_lb_controller_policy  = lookup(each.value.policy, "attach_aws_lb_controller_policy", false)
  attach_cluster_autoscaler_policy = lookup(each.value.policy, "attach_cluster_autoscaler_policy", false)
  cluster_autoscaler_cluster_names = [local.name]
  attach_external_secrets_policy   = lookup(each.value.policy, "attach_external_secrets_policy", false)
  # The app's own secrets, platform secrets (the Tailscale operator's OAuth client), and the
  # RDS-managed master password secret.
  external_secrets_secrets_manager_arns = [
    "arn:aws:secretsmanager:${var.region}:${local.account_id}:secret:${var.environment}/webapp/*",
    "arn:aws:secretsmanager:${var.region}:${local.account_id}:secret:${var.environment}/platform/*",
    "arn:aws:secretsmanager:${var.region}:${local.account_id}:secret:rds!*",
  ]
  external_secrets_create_permission = false

  # The EBS CSI association is made by the add-on itself (above), so skip it here.
  associations = each.key == "ebs-csi" ? {} : {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = each.value.namespace
      service_account = each.value.service_account
    }
  }
}
