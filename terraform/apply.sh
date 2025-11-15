#!/bin/bash
# Helper script to apply infrastructure and auto-import existing IP
# Usage: ./apply.sh
#
# This script will:
# 1. Try to import existing IP if it exists in GCP
# 2. Run terraform apply
# 3. If IP import fails (doesn't exist), terraform will create it

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

GCP_PROJECT_ID="${TF_VAR_project_id:-${GCP_PROJECT_ID:-ai-cluster-478022}}"
GCP_REGION="${TF_VAR_region:-${GCP_REGION:-europe-west1}}"
GCP_ZONE="${TF_VAR_zone:-${GCP_ZONE:-europe-west1-b}}"
CLUSTER_NAME="${TF_VAR_cluster_name:-open-webui-cluster}"
IP_NAME="${CLUSTER_NAME}-ingress-ip"

echo "🚀 Applying infrastructure..."
echo ""

# Initialize terraform if needed
if [ ! -d ".terraform" ]; then
    echo "📝 Initializing terraform..."
    terraform init
fi

# Check if IP exists in GCP but not in terraform state
IP_EXISTS_IN_GCP=$(gcloud compute addresses describe "${IP_NAME}" \
    --region="${GCP_REGION}" \
    --project="${GCP_PROJECT_ID}" \
    --format="value(name)" 2>/dev/null || echo "")

IP_IN_STATE=$(terraform state list 2>/dev/null | grep "google_compute_address.ingress_ip" || echo "")

if [ -n "${IP_EXISTS_IN_GCP}" ] && [ -z "${IP_IN_STATE}" ]; then
    echo "📍 Found existing IP in GCP, importing to terraform state..."
    echo "   IP: ${IP_EXISTS_IN_GCP}"
    
    IMPORT_ID="projects/${GCP_PROJECT_ID}/regions/${GCP_REGION}/addresses/${IP_NAME}"
    
    if terraform import google_compute_address.ingress_ip "${IMPORT_ID}" 2>/dev/null; then
        echo "   ✅ IP imported successfully"
    else
        echo "   ⚠️  Import failed, terraform will try to create it (may fail if IP exists)"
    fi
    echo ""
fi

# Refresh state to sync with GCP
echo "🔄 Refreshing terraform state..."
TF_VAR_project_id="${GCP_PROJECT_ID}" \
TF_VAR_region="${GCP_REGION}" \
TF_VAR_zone="${GCP_ZONE}" \
TF_VAR_cluster_name="${CLUSTER_NAME}" \
terraform refresh > /dev/null 2>&1 || true

# Check if IP is in state
IP_IN_STATE=$(terraform state list 2>/dev/null | grep "google_compute_address.ingress_ip" || echo "")

# Apply infrastructure
echo "🏗️  Applying infrastructure..."

# If IP is in state, use -target to exclude it from plan (prevents destroy error)
if [ -n "${IP_IN_STATE}" ]; then
    echo "   📍 IP already in state, applying with -target to preserve it..."
    TF_VAR_project_id="${GCP_PROJECT_ID}" \
    TF_VAR_region="${GCP_REGION}" \
    TF_VAR_zone="${GCP_ZONE}" \
    TF_VAR_cluster_name="${CLUSTER_NAME}" \
    terraform apply \
      -target=google_container_cluster.cluster \
      -target=google_container_node_pool.primary \
      -target=google_project_service.apis
else
    # IP not in state, normal apply
    TF_VAR_project_id="${GCP_PROJECT_ID}" \
    TF_VAR_region="${GCP_REGION}" \
    TF_VAR_zone="${GCP_ZONE}" \
    TF_VAR_cluster_name="${CLUSTER_NAME}" \
    terraform apply
fi

echo ""
echo "✅ Infrastructure applied!"
INGRESS_IP=$(TF_VAR_project_id="${GCP_PROJECT_ID}" \
  TF_VAR_region="${GCP_REGION}" \
  TF_VAR_zone="${GCP_ZONE}" \
  TF_VAR_cluster_name="${CLUSTER_NAME}" \
  terraform output -raw ingress_ip 2>/dev/null || echo "")
if [ -n "${INGRESS_IP}" ]; then
    echo "📍 Static IP: ${INGRESS_IP}"
fi

echo ""
echo "📝 To deploy application, run:"
echo "   ./scripts/deploy-to-k8s.sh"
echo ""
echo "   Or from project root: ./scripts/deploy-to-k8s.sh"

