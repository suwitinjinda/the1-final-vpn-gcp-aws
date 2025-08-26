# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  four_interface_ext_gwys = [for i in range(floor(var.num_tunnels / 4)) :
    { key : i, redundancy_type = "FOUR_IPS_REDUNDANCY" }
  ]
  two_interface_ext_gwys = [for i in range(ceil(var.num_tunnels / 4) - length(local.four_interface_ext_gwys)) :
    {
      key : i + length(local.four_interface_ext_gwys),
      redundancy_type = "TWO_IPS_REDUNDANCY"
    } if var.num_tunnels % 4 != 0
  ]
  num_ext_gwys = concat(local.four_interface_ext_gwys, local.two_interface_ext_gwys)
  aws_vpn_conn_addresses = {
    for k, v in chunklist([
      for k, v in flatten([
        for k, v in aws_vpn_connection.vpn_conn :
        [v.tunnel1_address, v.tunnel2_address]
      ]) : v
    ], 4) :
    k => v
  }
  ##add second aws tgw
  aws_vpn_conn_addresses1 = {
    for k, v in chunklist([
      for k, v in flatten([
        for k, v in aws_vpn_connection.vpn_conn1 :
        [v.tunnel1_address, v.tunnel2_address]
      ]) : v
    ], 4) :
    k => v
  }
   ##end add second aws tgw
  tunnels = chunklist(flatten([
    for i in range(length(local.num_ext_gwys)) : [
      for k, v in setproduct(range(2), chunklist(range(4), 2)) :
      {
        ext_gwy : i,
        peer_gwy_interface : k,
        vpn_gwy_interface : v[0] % 2
      }
    ]
  ]), var.num_tunnels)[0]
  bgp_sessions = {
    for k, v in flatten([
      for k, v in aws_vpn_connection.vpn_conn :
      [
        {
          ip_address : v.tunnel1_cgw_inside_address,
          peer_ip_address : v.tunnel1_vgw_inside_address
        },
        {
          ip_address : v.tunnel2_cgw_inside_address,
          peer_ip_address : v.tunnel2_vgw_inside_address
        }
      ]
    ]) : k => v
  }
  ##add second aws tgw
  bgp_sessions1 = {
    for k, v in flatten([
      for k, v in aws_vpn_connection.vpn_conn1 :
      [
        {
          ip_address : v.tunnel1_cgw_inside_address,
          peer_ip_address : v.tunnel1_vgw_inside_address
        },
        {
          ip_address : v.tunnel2_cgw_inside_address,
          peer_ip_address : v.tunnel2_vgw_inside_address
        }
      ]
    ]) : k => v
  }
  ##end add second aws tgw
}

resource "google_compute_ha_vpn_gateway" "gwy" {
  name    = "${var.prefix}-ha-vpn-gwy-aws"
  network = var.gcp_network
  region  = var.vpn_gwy_region
}

resource "google_compute_external_vpn_gateway" "ext_gwy" {
  for_each = { for k, v in local.num_ext_gwys : k => v }

  name            = "${var.prefix}-ext-vpn-gwy-prod"
  redundancy_type = each.value["redundancy_type"]
  dynamic "interface" {
    for_each = local.aws_vpn_conn_addresses[each.key]
    content {
      id         = interface.key
      ip_address = interface.value
    }
  }
}

resource "google_compute_router" "router" {
  name    = "${var.prefix}-vpn-router-aws"
  network = var.gcp_network
  region  = var.vpn_gwy_region
  bgp {
    asn            = var.gcp_router_asn
    advertise_mode = "CUSTOM"

    advertised_ip_ranges {
      range       = var.advertise_route
      description = var.advertise_route_des
    }
  }
}

resource "google_compute_vpn_tunnel" "tunnel" {
  for_each = { for k, v in local.tunnels : k => v }

  name                            = "${var.prefix}-tunnel-prod-${each.key}"
  shared_secret                   = var.shared_secret
  peer_external_gateway           = google_compute_external_vpn_gateway.ext_gwy[each.value["ext_gwy"]].name
  peer_external_gateway_interface = each.value["peer_gwy_interface"]
  region                          = var.vpn_gwy_region
  router                          = google_compute_router.router.name
  ike_version                     = "2"
  vpn_gateway                     = google_compute_ha_vpn_gateway.gwy.id
  vpn_gateway_interface           = each.value["vpn_gwy_interface"]
}

resource "google_compute_router_interface" "interface" {
  for_each = local.bgp_sessions

  name       = "${var.prefix}-interface-prod-${each.key}"
  router     = google_compute_router.router.name
  region     = var.vpn_gwy_region
  ip_range   = "${each.value["ip_address"]}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel[each.key].name
}

resource "google_compute_router_peer" "peer" {
  for_each = local.bgp_sessions

  name            = "${var.prefix}-peer-prod-${each.key}"
  interface       = "${var.prefix}-interface-prod-${each.key}"
  peer_asn        = var.aws_router_asn
  ip_address      = each.value["ip_address"]
  peer_ip_address = each.value["peer_ip_address"]
  router          = google_compute_router.router.name
  region          = var.vpn_gwy_region
}

##add second aws tgw
resource "google_compute_external_vpn_gateway" "ext_gwy1" {
  for_each = { for k, v in local.num_ext_gwys : k => v }

  name            = "${var.prefix}-ext-vpn-gwy-nonprod"
  redundancy_type = each.value["redundancy_type"]
  dynamic "interface" {
    for_each = local.aws_vpn_conn_addresses1[each.key]
    content {
      id         = interface.key
      ip_address = interface.value
    }
  }
}

resource "google_compute_vpn_tunnel" "tunnel1" {
  for_each = { for k, v in local.tunnels : k => v }

  name                            = "${var.prefix}-tunnel-nonprod-${each.key}"
  shared_secret                   = var.shared_secret
  peer_external_gateway           = google_compute_external_vpn_gateway.ext_gwy1[each.value["ext_gwy"]].name
  peer_external_gateway_interface = each.value["peer_gwy_interface"]
  region                          = var.vpn_gwy_region
  router                          = google_compute_router.router.name
  ike_version                     = "2"
  vpn_gateway                     = google_compute_ha_vpn_gateway.gwy.id
  vpn_gateway_interface           = each.value["vpn_gwy_interface"]
}

resource "google_compute_router_interface" "interface1" {
  for_each = local.bgp_sessions1

  name       = "${var.prefix}-interface-nonprod-${each.key}"
  router     = google_compute_router.router.name
  region     = var.vpn_gwy_region
  ip_range   = "${each.value["ip_address"]}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel1[each.key].name
}

resource "google_compute_router_peer" "peer1" {
  for_each = local.bgp_sessions1

  name            = "${var.prefix}-peer-nonprod-${each.key}"
  interface       = "${var.prefix}-interface-nonprod-${each.key}"
  peer_asn        = var.aws_router_asn_2
  ip_address      = each.value["ip_address"]
  peer_ip_address = each.value["peer_ip_address"]
  router          = google_compute_router.router.name
  region          = var.vpn_gwy_region
}
##end add second aws tgw