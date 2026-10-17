resource "aws_route53_zone" "public" {
  count = var.domain == "" ? 0 : 1
  name  = var.domain
}
