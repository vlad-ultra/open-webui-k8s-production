#!/bin/bash
# Helper script to destroy infrastructure while preserving IP
# Usage: ./scripts/destroy-infra.sh
#
# This script destroys all resources EXCEPT the IP address.
# IP is preserved in GCP and will be reused on next apply.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Set default values for terraform variables (same as apply.sh)
GCP_PROJECT_ID="${TF_VAR_project_id:-${GCP_PROJECT_ID:-ai-cluster-478022}}"
GCP_REGION="${TF_VAR_region:-${GCP_REGION:-europe-west1}}"
GCP_ZONE="${TF_VAR_zone:-${GCP_ZONE:-europe-west1-b}}"
CLUSTER_NAME="${TF_VAR_cluster_name:-${CLUSTER_NAME:-open-webui-cluster}}"

PRESERVE_IP="${PRESERVE_IP:-true}"  # set to 'false' to fully destroy including IP

if [ "$PRESERVE_IP" = "false" ]; then
    echo "Destroying ALL infrastructure (including static IP)..."
else
    echo "Destroying infrastructure (IP will be preserved)..."
fi
echo ""

# Initialize terraform if needed
cd "${PROJECT_ROOT}/terraform"
if [ ! -d ".terraform" ]; then
    echo "   Initializing terraform..."
    terraform init
fi

# Ensure Terraform picks up variables in subsequent commands
export TF_VAR_project_id="${GCP_PROJECT_ID}"
export TF_VAR_region="${GCP_REGION}"
export TF_VAR_zone="${GCP_ZONE}"
export TF_VAR_cluster_name="${CLUSTER_NAME}"

if [ "$PRESERVE_IP" = "false" ]; then
  echo "   Running full terraform destroy..."
  terraform destroy -auto-approve
else
  # Destroy all resources EXCEPT the IP address using -target
  echo "   Destroying cluster and node pool..."
  echo "   Using -target to preserve static IP address..."
  terraform destroy -auto-approve \
    -target=google_container_cluster.cluster \
    -target=google_container_node_pool.primary \
    -target=google_project_service.apis
fi

echo ""
echo "✅ Infrastructure destroyed!"
if [ "$PRESERVE_IP" = "false" ]; then
  echo "🗑️  Static IP removed"
else
  echo "📍 Static IP preserved in GCP (will be reused on next apply)"
fi

