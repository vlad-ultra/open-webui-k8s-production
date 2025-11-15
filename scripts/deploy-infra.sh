#!/bin/bash
# Script to deploy infrastructure with Terraform
# Usage: ./scripts/deploy-infra.sh
# 
# This script will:
# 1. Initialize Terraform (if needed)
# 2. Import existing IP address (if exists in GCP but not in state)
# 3. Apply Terraform infrastructure (GKE cluster, node pool, static IP)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

# Set default values for terraform variables
GCP_PROJECT_ID="${TF_VAR_project_id:-${GCP_PROJECT_ID:-ai-cluster-478022}}"
GCP_REGION="${TF_VAR_region:-${GCP_REGION:-europe-west1}}"
GCP_ZONE="${TF_VAR_zone:-${GCP_ZONE:-europe-west1-b}}"
CLUSTER_NAME="${TF_VAR_cluster_name:-${CLUSTER_NAME:-open-webui-cluster}}"
IP_NAME="${CLUSTER_NAME}-ingress-ip"

echo "🚀 Deploying infrastructure with Terraform..."
echo ""

cd "${PROJECT_ROOT}/terraform"

# Initialize terraform if needed
if [ ! -d ".terraform" ]; then
    echo "Step 1: Initializing terraform..."
    terraform init
    echo "    Terraform initialized"
    echo ""
else
    echo "Step 1: Terraform already initialized"
    echo ""
fi

# Check if IP exists in GCP but not in terraform state
echo "Step 2: Checking for existing IP address..."
IP_EXISTS_IN_GCP=$(gcloud compute addresses describe "${IP_NAME}" \
    --region="${GCP_REGION}" \
    --project="${GCP_PROJECT_ID}" \
    --format="value(name)" 2>/dev/null || echo "")

IP_IN_STATE=$(terraform state list 2>/dev/null | grep "google_compute_address.ingress_ip" || echo "")

if [ -n "${IP_EXISTS_IN_GCP}" ] && [ -z "${IP_IN_STATE}" ]; then
    echo "   Found existing IP in GCP, importing to terraform state..."
    IMPORT_ID="projects/${GCP_PROJECT_ID}/regions/${GCP_REGION}/addresses/${IP_NAME}"
    if terraform import google_compute_address.ingress_ip "${IMPORT_ID}" 2>/dev/null; then
        echo "    IP imported successfully"
    else
        echo "    Could not import IP (will be created if needed)"
    fi
else
    if [ -n "${IP_IN_STATE}" ]; then
        echo "    IP already in terraform state"
    else
        echo "     IP will be created by Terraform"
    fi
fi
echo ""

# Refresh state
echo "Step 3: Refreshing terraform state..."
TF_VAR_project_id="${GCP_PROJECT_ID}" \
TF_VAR_region="${GCP_REGION}" \
TF_VAR_zone="${GCP_ZONE}" \
TF_VAR_cluster_name="${CLUSTER_NAME}" \
terraform refresh || true
echo "    State refreshed"
echo ""

# Check if IP is in state
IP_IN_STATE=$(terraform state list 2>/dev/null | grep "google_compute_address.ingress_ip" || echo "")

# Apply infrastructure
echo "Step 4: Applying infrastructure..."
if [ -n "${IP_IN_STATE}" ]; then
    echo "   Using -target to preserve existing IP..."
    TF_VAR_project_id="${GCP_PROJECT_ID}" \
    TF_VAR_region="${GCP_REGION}" \
    TF_VAR_zone="${GCP_ZONE}" \
    TF_VAR_cluster_name="${CLUSTER_NAME}" \
    terraform apply -auto-approve \
      -target=google_container_cluster.cluster \
      -target=google_container_node_pool.primary \
      -target=google_project_service.apis
else
    echo "   Full infrastructure apply..."
    TF_VAR_project_id="${GCP_PROJECT_ID}" \
    TF_VAR_region="${GCP_REGION}" \
    TF_VAR_zone="${GCP_ZONE}" \
    TF_VAR_cluster_name="${CLUSTER_NAME}" \
    terraform apply -auto-approve
fi

echo ""
echo " Infrastructure deployed successfully!"
echo ""
echo " Infrastructure details:"
echo "   Project: ${GCP_PROJECT_ID}"
echo "   Region: ${GCP_REGION}"
echo "   Zone: ${GCP_ZONE}"
echo "   Cluster: ${CLUSTER_NAME}"
echo ""

# Get static IP
INGRESS_IP=$(TF_VAR_project_id="${GCP_PROJECT_ID}" \
  TF_VAR_region="${GCP_REGION}" \
  TF_VAR_zone="${GCP_ZONE}" \
  TF_VAR_cluster_name="${CLUSTER_NAME}" \
  terraform output -raw ingress_ip 2>/dev/null || echo "")

if [ -z "${INGRESS_IP}" ]; then
    INGRESS_IP=$(gcloud compute addresses describe "${IP_NAME}" \
        --region="${GCP_REGION}" \
        --project="${GCP_PROJECT_ID}" \
        --format="value(address)" 2>/dev/null || echo "")
fi

if [ -n "${INGRESS_IP}" ]; then
    echo "   Static IP: ${INGRESS_IP}"
fi

echo ""
echo "💡 Next step: Deploy application to Kubernetes"
echo "   Run: ./scripts/deploy-to-k8s.sh"

