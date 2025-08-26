# GCP Service Account to impersonate for deployment (e.g., "gcp-vpn-admin@your-project-id.iam.gserviceaccount.com") require compute network admin permission
impersonate_service_account = "terraform-gcp-aws-vpn-sa@the1-service-gke-stg.iam.gserviceaccount.com"

# Your existing Google Cloud Project ID
project_id = "the1-service-gke-stg"

subnet_regions = ["asia-southeast1"] # Example: subnet_regions = ["asia-southeast1", "asia-east1"]

vpn_gwy_region = "asia-southeast1" # e.g., "asia-southeast1"

gcp_network         = "the1-vpc" # existing VPC name

prefix = "the1"

advertise_route = "10.16.0.0/16"

advertise_route_des = "the1 GCP subnet"

gcp_router_asn = "65002" # ASN for the Google Cloud Router (e.g., 65000-65534 for private use) create new

# AWS configuration from existing TGW
aws_router_asn = "64512" # ASN for the AWS Router prod

aws_router_asn_2 = "64513" # ASN for the AWS Router non prod

num_tunnels = 4 # Or 6, 8, etc. Total number of VPN tunnels. Must be an even number and >= 4 for HA.


# Shared secret for the VPN tunnels. Keep this secure and complex.
# This should ideally be generated or retrieved from a secure secret manager.
shared_secret = "YourHighlySecureAndComplexSharedSecretForVPN"