variable "region"       { type = string }
variable "loadbalancer" { type = string }
variable "zone"         { type = string }
variable "instances"    { type = set(string) }

# Terraform setup stuff, required providers, where they are sourced from, and
# the provider's configuration requirements.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.39.0"
    }
  }
}

data "aws_instance" "nodes" {
  for_each = var.instances

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

data "aws_lb" "loadbalancer" {
  name = var.loadbalancer
}

data "aws_route53_zone" "dns_zone" {
  name         = "${var.zone}"
}

resource "aws_route53_record" "node" {
  for_each = data.aws_instance.nodes
  zone_id = data.aws_route53_zone.dns_zone.zone_id
  name    = "${each.value.tags["Name"]}.${var.zone}"
  type    = "A"
  ttl     = 300
  records = [each.value.private_ip]
}

resource "aws_route53_record" "loadbalancer" {
  zone_id = data.aws_route53_zone.dns_zone.zone_id
  name    = "${var.loadbalancer}.${var.zone}"
  type    = "CNAME"
  ttl     = 300
  records = [data.aws_lb.loadbalancer.dns_name]
}
