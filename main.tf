variable "project"      { type = string }
variable "region"       { type = string }
variable "loadbalancer" { type = string }
variable "instances"    { type = set(string) }

# Terraform setup stuff, required providers, where they are sourced from, and
# the provider's configuration requirements.
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.68.0"
    }
  }
}

# GCP region and project to operating within
provider "google" {
  project = var.project
  region  = var.region
}

data "google_compute_zones" "available" {
  status = "UP"
}

locals {
  domain       = "cody.automationdemos.com."
  zones        = data.google_compute_zones.available.names
  permutations = flatten([ for i in var.instances : 
    [for z in local.zones : { "${i}/${z}" = { "name" = i, "zone" = z }}]
  ])
  instance_zone_map = { for p in local.permutations :
    keys(p)[0] => values(p)[0]
  }
  collected_instances = {
    for i in tolist(data.google_compute_instance.nodes[*])[0] :
      i.name => i.network_interface[0].network_ip if i.instance_id != null
  }
  collected_lb = "${data.google_compute_forwarding_rule.loadbalancer.service_name}."
}

data "google_compute_instance" "nodes" {
  for_each = local.instance_zone_map
  name = each.value["name"]
  zone = each.value["zone"]
}

data "google_compute_forwarding_rule" "loadbalancer" {
  name = var.loadbalancer
}

resource "google_dns_record_set" "node" {
  for_each = local.collected_instances
  name = "${each.key}.${local.domain}"
  type = "A"
  ttl  = 300

  managed_zone = "automationdemos"

  rrdatas = [each.value]
}

resource "google_dns_record_set" "loadbalancer" {
  name = "${var.loadbalancer}.${local.domain}"
  type = "CNAME"
  ttl  = 300

  managed_zone = "automationdemos"

  rrdatas = [local.collected_lb]
}
