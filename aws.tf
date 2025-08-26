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
  default_num_ha_vpn_interfaces = 2
}

resource "aws_customer_gateway" "gwy" {
  count = local.default_num_ha_vpn_interfaces

  device_name = "${var.prefix}-gwy-${count.index}"
  bgp_asn     = var.gcp_router_asn
  type        = "ipsec.1"
  ip_address  = google_compute_ha_vpn_gateway.gwy.vpn_interfaces[count.index]["ip_address"]
}

resource "aws_vpn_connection" "vpn_conn" {
  count = var.num_tunnels / 2

  customer_gateway_id   = aws_customer_gateway.gwy[count.index % 2].id
  type                  = "ipsec.1"
  transit_gateway_id    = "" # need TGW ID for prod
  tunnel1_preshared_key = var.shared_secret
  tunnel2_preshared_key = var.shared_secret

  tags = {
    Name = "${var.prefix}-vpn-connn-prod"
  }
}

resource "aws_vpn_connection" "vpn_conn1" {
  count = var.num_tunnels / 2

  customer_gateway_id   = aws_customer_gateway.gwy[count.index % 2].id
  type                  = "ipsec.1"
  transit_gateway_id    = "" # need TGW ID for nonprod
  tunnel1_preshared_key = var.shared_secret
  tunnel2_preshared_key = var.shared_secret

  tags = {
    Name = "${var.prefix}-vpn-connn-nonprod"
  }
}