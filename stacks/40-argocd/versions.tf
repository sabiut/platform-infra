terraform {
  required_version = ">= 1.11"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.60" }
    helm       = { source = "hashicorp/helm", version = "~> 3.1" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.2" }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.region
  default_tags { tags = { project = "eks-gitops-platform", stack = "40-argocd", environment = var.environment, managed_by = "terraform" } }
}

locals {
  kube = {
    host                   = local.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(local.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--region", var.region, "--cluster-name", local.eks.cluster_name]
    }
  }
}

provider "helm" {
  kubernetes = local.kube
}

provider "kubernetes" {
  host                   = local.kube.host
  cluster_ca_certificate = local.kube.cluster_ca_certificate
  exec {
    api_version = local.kube.exec.api_version
    command     = local.kube.exec.command
    args        = local.kube.exec.args
  }
}
