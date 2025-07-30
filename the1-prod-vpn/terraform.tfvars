# GCP Service Account to impersonate for deployment (e.g., "gcp-vpn-admin@your-project-id.iam.gserviceaccount.com")
impersonate_service_account = "terraform-gcp-aws-vpn-sa@the1-service-gke-stg.iam.gserviceaccount.com"

# Your existing Google Cloud Project ID
project_id = "the1-service-gke-stg"

subnet_regions = ["asia-southeast1"] # Example: subnet_regions = ["asia-southeast1", "asia-east1"]

vpn_gwy_region = "asia-southeast1" # e.g., "asia-southeast1"

gcp_network         = "the1-vpc" # existing VPC name

prefix = "the1-prod"

advertise_route = "10.16.0.0/16"

advertise_route_des = "prod subnet"

gcp_router_asn = "65002" # ASN for the Google Cloud Router (e.g., 65000-65534 for private use)

# AWS configuration
aws_router_asn = "64512" # ASN for the AWS Router (e.g., 64512-65534 for private use)

num_tunnels = 4 # Or 6, 8, etc. Total number of VPN tunnels. Must be an even number and >= 4 for HA.

aws_private_subnets = ["subnet-00138e69db2xxxxxx"] # existing VPC of aws

aws_vpc_id          = "vpc-066fa46561xxxxxxx" # existing VPC of aws

# Shared secret for the VPN tunnels. Keep this secure and complex.
# This should ideally be generated or retrieved from a secure secret manager.
shared_secret = "YourHighlySecureAndComplexSharedSecretForVPN"