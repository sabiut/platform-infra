# Outputs of 20-eks; placeholders in plan-only mode (see 20-eks/remote_state.tf).
data "terraform_remote_state" "eks" {
  count   = var.state_bucket == "" ? 0 : 1
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "${var.environment}/${var.region}/20-eks.tfstate"
    region = var.state_region
  }
}

locals {
  plan_only = var.state_bucket == ""
  eks = try(data.terraform_remote_state.eks[0].outputs, {
    cluster_name     = "${var.environment}-${var.region}"
    cluster_endpoint = "https://PLANONLY.gr7.${var.region}.eks.amazonaws.com"
    # A throwaway self-signed certificate (CN "PLANONLY placeholder"): the kubernetes provider
    # insists on valid PEM even at plan time.
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURSekNDQWkrZ0F3SUJBZ0lVTSttbGJRTmZSOUFkTEdaRnNxSDkwUFM3V1Frd0RRWUpLb1pJaHZjTkFRRUwKQlFBd016RXhNQzhHQTFVRUF3d29VRXhCVGs5T1RGa2djR3hoWTJWb2IyeGtaWElzSUc1dmRDQmhJSEpsWVd3ZwpZMngxYzNSbGNqQWVGdzB5TmpFd01UWXdOREk1TURSYUZ3MHpOakV3TVRNd05ESTVNRFJhTURNeE1UQXZCZ05WCkJBTU1LRkJNUVU1UFRreFpJSEJzWVdObGFHOXNaR1Z5TENCdWIzUWdZU0J5WldGc0lHTnNkWE4wWlhJd2dnRWkKTUEwR0NTcUdTSWIzRFFFQkFRVUFBNElCRHdBd2dnRUtBb0lCQVFEQ0VmSzl0b1ZIR3hudmpGaUp6UXZSeFdUcQpkQndtUTZKc0xhbWJFSE1mbG4yejFzQlRjMmdKaFo0TkRjbC9MZmdiOUZEcG01alU3dnhvbzZPY3BpTFYxbDV2Ck5iL3RFV1p6OUNId25ENCt2SU1CdHhhdWQ5TlVmdWZSenBhREZPSVA0eFlHaXVEUTBkU3ZUdmdDS2hLUzdvUUEKZ2dXNXFHSzdHZHFnYjVTdEJTeXhuQjhmTGJnK09MTUx4WnJZT1FFV2xBYzBjbytPb1B0TVArRis1OU5EU0s4WAozTk9xeEdyY2xVTXhXY2EyMVA1NEVoU3F5eHM3TzFBWHdqUDhwaUF1VjRvaytnWms4bmRuWUIzV2FodXVzQ2JECk8yMWcxNDlZWHd2a1h2Y0Q2K283QTBDVTRpd0lLWVEvSndET3VyUnhEZDhGaVhhdWhOVm1PcjdzSHd1N0FnTUIKQUFHalV6QlJNQjBHQTFVZERnUVdCQlRUTnRwWG5WbkREK2V5QTEvcndhQkxLRFA3dnpBZkJnTlZIU01FR0RBVwpnQlRUTnRwWG5WbkREK2V5QTEvcndhQkxLRFA3dnpBUEJnTlZIUk1CQWY4RUJUQURBUUgvTUEwR0NTcUdTSWIzCkRRRUJDd1VBQTRJQkFRQjcwRWNNcVc3NDZ3U0lSWjZKb3dNY09RZGJoRUpKQmp4WlV0TTg2eWhPQ2VsMzZJb3oKVXNyZUgxakFuVWxickxXUzZReHR1c1hPMVBmTHJmR0FtRytBajBBN2U1MnBZUUx0RDEzZ0FIaUI1cUhFdUVWSgptd0UvaFR0OUM3WVhsZHJ3NHQwczdqcHlvTVlXZ2hkVEpVeTFTNGkzYVJoZXk3UXZ2TkMwMytUR1VHaW94dlZzCm9hVlc1bElnVHhrYk1zNHVvVzlKb0ZuWXNaL3NKTENOVGFBRDArbGwralovY0tpMTBEVEpLd29pZHdkdDgyaEkKRkxwRzhrdFM4MnRSMnZOZmh3MXFGY0w3QmJMTURoUnUyU0c1MGNPYTQxcEFQTnZ4MjI5T1EydVY4VXJJYURkVQpGTi9LSlpjTGVmcXJEMmprV0VoQS9WZmlFYkhzT2ZPaFI0U1MKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
  })
}
