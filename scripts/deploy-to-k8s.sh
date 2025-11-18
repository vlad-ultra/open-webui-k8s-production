#!/bin/bash
# Script to deploy application to Kubernetes
# Usage: ./scripts/deploy-to-k8s.sh
# 
# Prerequisites: Infrastructure must be deployed first with ./scripts/deploy-infra.sh
# 
# This script will:
# 1. Get cluster credentials
# 2. Install NGINX Ingress with static IP
# 3. Load SSL certificates from GCS bucket (cert-manager disabled)
# 4. Deploy Open WebUI via Helm
# 5. Restore database from backup (if exists)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

NAMESPACE="ai"
APP_NAME="open-webui"
BACKUP_BUCKET="open-webui-backups"
DOMAIN="${DOMAIN:-ai.svdevops.tech}"
SECRET_NAME="open-webui-tls"
# Set default values for terraform variables
GCP_PROJECT_ID="${TF_VAR_project_id:-${GCP_PROJECT_ID:-ai-cluster-478022}}"
GCP_REGION="${TF_VAR_region:-${GCP_REGION:-europe-west1}}"
GCP_ZONE="${TF_VAR_zone:-${GCP_ZONE:-europe-west1-b}}"
CLUSTER_NAME="${TF_VAR_cluster_name:-${CLUSTER_NAME:-open-webui-cluster}}"
IP_NAME="${CLUSTER_NAME}-ingress-ip"

echo " Deploying application to Kubernetes..."
echo ""
echo "  Prerequisites: Infrastructure must be deployed first"
echo "   If not deployed, run: ./scripts/deploy-infra.sh"
echo ""

# Step 1: Get cluster credentials
echo "Step 1: Getting cluster credentials..."

# Check if cluster exists
if ! gcloud container clusters describe "${CLUSTER_NAME}" \
    --zone "${GCP_ZONE}" \
    --project "${GCP_PROJECT_ID}" > /dev/null 2>&1; then
    echo "   Error: Cluster '${CLUSTER_NAME}' not found after terraform apply"
    exit 1
fi

export USE_GKE_GCLOUD_AUTH_PLUGIN=True
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --zone "${GCP_ZONE}" \
    --project "${GCP_PROJECT_ID}"

echo "   Credentials configured"
echo ""

# Step 2: Check cluster status
echo "Step 2: Checking cluster status..."
ATTEMPTS=12
SLEEP=10
for i in $(seq 1 ${ATTEMPTS}); do
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "   Cluster credentials configured"
        break
    fi
    echo "   Waiting for API server to become reachable (${i}/${ATTEMPTS})..."
    sleep ${SLEEP}
done
kubectl cluster-info || { echo "   Error: Kubernetes API not reachable"; exit 1; }
echo "   Cluster credentials configured"
echo ""

# Step 3: Get static IP from terraform or GCP
echo "Step 3: Getting static IP address..."
cd "${PROJECT_ROOT}/terraform"
INGRESS_IP=$(TF_VAR_project_id="${GCP_PROJECT_ID}" \
  TF_VAR_region="${GCP_REGION}" \
  TF_VAR_zone="${GCP_ZONE}" \
  TF_VAR_cluster_name="${CLUSTER_NAME}" \
  terraform output -raw ingress_ip 2>/dev/null || echo "")
cd "${PROJECT_ROOT}"

if [ -z "${INGRESS_IP}" ]; then
    echo "   Could not get IP from terraform output, checking GCP..."
    INGRESS_IP=$(gcloud compute addresses describe "${IP_NAME}" \
        --region="${GCP_REGION}" \
        --project="${GCP_PROJECT_ID}" \
        --format="value(address)" 2>/dev/null || echo "")
fi

if [ -z "${INGRESS_IP}" ]; then
    echo "   Error: Could not find static IP address"
    echo "   Make sure infrastructure is deployed: ./scripts/deploy-infra.sh"
    exit 1
fi

echo "    Static IP: ${INGRESS_IP}"
echo ""

# Step 4: Install NGINX Ingress
echo "Step 4: Installing NGINX Ingress..."
echo "   Adding Helm repository..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || echo "   Repository already exists"
echo "   Updating Helm repositories..."
helm repo update

# Function to clear stuck Helm operations
clear_helm_pending() {
    local RELEASE_NAME=$1
    local NAMESPACE=$2
    echo "   Attempting to clear pending Helm operations for ${RELEASE_NAME}..."
    
    # Try rollback first (safest option)
    echo "   Trying rollback..."
    helm rollback "${RELEASE_NAME}" -n "${NAMESPACE}" 2>/dev/null || true
    sleep 3
    
    # Check if release still exists and get its status
    if helm list -n "${NAMESPACE}" 2>/dev/null | grep -q "${RELEASE_NAME}"; then
        RELEASE_STATUS=$(helm status "${RELEASE_NAME}" -n "${NAMESPACE}" -o json 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "")
        echo "   Current release status: ${RELEASE_STATUS}"
        
        # If still pending, try to find and delete the pending release secret
        if [[ "$RELEASE_STATUS" == *"pending"* ]]; then
            echo "   Warning: Release still in pending state, attempting to clear..."
            # Find all Helm release secrets for this release
            SECRETS=$(kubectl get secrets -n "${NAMESPACE}" -l owner=helm 2>/dev/null | grep "sh.helm.release.v1.${RELEASE_NAME}.v" | awk '{print $1}' || echo "")
            
            if [ -n "${SECRETS}" ]; then
                # Get the latest secret (highest version number)
                LATEST_SECRET=$(echo "${SECRETS}" | sort -V -r | head -1)
                echo "   Found latest release secret: ${LATEST_SECRET}"
                
                # Try to get the status from the secret
                SECRET_STATUS=$(kubectl get secret "${LATEST_SECRET}" -n "${NAMESPACE}" -o jsonpath='{.metadata.labels.status}' 2>/dev/null || echo "")
                
                if [[ "$SECRET_STATUS" == *"pending"* ]] || [[ -z "$SECRET_STATUS" ]]; then
                    echo "   Deleting pending release secret to clear stuck state..."
                    kubectl delete secret "${LATEST_SECRET}" -n "${NAMESPACE}" 2>/dev/null || true
                    sleep 2
                fi
            fi
        fi
    fi
}

migrate_pvc() {
    local REASON="$1"
    if [ -z "${PVC_NAME:-}" ]; then
        PVC_NAME="open-webui-pvc"
    fi
    echo "   WARNING: PVC '${PVC_NAME}' needs to be recreated (${REASON})"
    echo "   This will:"
    echo "     1. Scale down deployment to 0 replicas"
    echo "     2. Delete old PVC (data will be restored from backup)"
    echo "     3. Allow Helm to create new PVC with correct specification"
    echo "     4. Restore data automatically via initContainer"
    
    if kubectl get deployment open-webui -n "${NAMESPACE}" >/dev/null 2>&1; then
        echo "   Scaling down deployment..."
        kubectl scale deployment open-webui -n "${NAMESPACE}" --replicas=0
        echo "   Waiting for pods to terminate..."
        sleep 15
        while kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=open-webui --no-headers 2>/dev/null | grep -v "No resources" | grep -q .; do
            echo "   Still waiting for pods to terminate..."
            sleep 5
        done
    fi
    
    echo "   Deleting old PVC '${PVC_NAME}'..."
    kubectl delete pvc "${PVC_NAME}" -n "${NAMESPACE}" --wait=true || {
        echo "   Warning: Failed to delete PVC. It may be in use. Trying force delete..."
        kubectl get pods -n "${NAMESPACE}" -o json | jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim?.claimName=="'${PVC_NAME}'") | .metadata.name' | while read pod; do
            if [ -n "${pod}" ]; then
                echo "   Force deleting pod ${pod} that may be using PVC..."
                kubectl delete pod "${pod}" -n "${NAMESPACE}" --force --grace-period=0 2>/dev/null || true
            fi
        done
        sleep 5
        kubectl delete pvc "${PVC_NAME}" -n "${NAMESPACE}" --wait=true || {
            echo "   Error: Could not delete PVC. Manual intervention may be required."
        }
    }
    echo "   Old PVC deleted. Helm will create a new PVC (access mode '${DESIRED_ACCESS_MODE}')"
    echo "   Data will be restored from backup automatically."
}

echo "   Installing/upgrading NGINX Ingress with static IP: ${INGRESS_IP}..."
# Check if ingress-nginx already exists
INGRESS_EXISTS=$(helm list -n ingress-nginx --filter ingress-nginx -q 2>/dev/null || echo "")
if [ -n "${INGRESS_EXISTS}" ]; then
    echo "   NGINX Ingress already installed, upgrading only if needed (no downtime)..."
    # Use --reuse-values to preserve existing configuration and avoid downtime
    UPGRADE_STRATEGY="--reuse-values"
else
    echo "   Installing NGINX Ingress for the first time..."
    UPGRADE_STRATEGY=""
fi

# Try to install/upgrade with retry logic
MAX_RETRIES=3
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Only set loadBalancerIP if not reusing values (to avoid IP change)
    if [ -z "${UPGRADE_STRATEGY}" ]; then
        HELM_CMD="helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --set controller.service.annotations.\"cloud\.google\.com/load-balancer-type\"=\"External\" \
        --set controller.service.loadBalancerIP=\"${INGRESS_IP}\" \
        --wait"
    else
        # When reusing values, only ensure IP is set if not already configured
        HELM_CMD="helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --reuse-values \
        --set controller.service.loadBalancerIP=\"${INGRESS_IP}\" \
        --wait"
    fi
    
    if eval "${HELM_CMD}" 2>&1 | tee /tmp/helm-output.log; then
        echo "   NGINX Ingress installed/upgraded successfully"
        break
    else
        if grep -q "another operation.*is in progress" /tmp/helm-output.log 2>/dev/null; then
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "   Warning: Detected pending Helm operation (attempt ${RETRY_COUNT}/${MAX_RETRIES})"
            clear_helm_pending "ingress-nginx" "ingress-nginx"
            echo "   Retrying installation..."
            sleep 5
        else
            echo "   Error: Helm installation failed with different error"
            cat /tmp/helm-output.log
            exit 1
        fi
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "   Error: Failed to install NGINX Ingress after ${MAX_RETRIES} attempts"
    exit 1
fi

echo "    NGINX Ingress installed with IP: ${INGRESS_IP}"
echo ""

# Step 5: Load SSL certificates from GCS bucket (Let's Encrypt preferred)
echo "Step 5: Loading SSL certificates from GCS bucket..."
DOMAIN="${DOMAIN:-ai.svdevops.tech}"
BACKUP_BUCKET="${BACKUP_BUCKET:-open-webui-backups}"

# Check if Let's Encrypt certificates exist in GCS bucket
GCS_CERT_FILE="gs://${BACKUP_BUCKET}/certs/${DOMAIN}.crt"
GCS_KEY_FILE="gs://${BACKUP_BUCKET}/certs/${DOMAIN}.key"

echo "   Checking for Let's Encrypt certificates in GCS bucket..."
if gsutil -q stat "${GCS_CERT_FILE}" 2>/dev/null && gsutil -q stat "${GCS_KEY_FILE}" 2>/dev/null; then
    # Download and check if it's Let's Encrypt certificate
    TEMP_CERT=$(mktemp)
    gsutil cp "${GCS_CERT_FILE}" "${TEMP_CERT}" 2>/dev/null
    CERT_ISSUER=$(openssl x509 -in "${TEMP_CERT}" -noout -issuer 2>/dev/null || echo "")
    rm -f "${TEMP_CERT}"
    
    if echo "${CERT_ISSUER}" | grep -q "Let's Encrypt\|R3\|X3"; then
        echo "   ✓ Let's Encrypt certificates found in GCS bucket, using them..."
        
        # Remove cert-manager annotation from Ingress to prevent auto-generation
        echo "   Removing cert-manager annotation from Ingress (using certificates from GCS)..."
        kubectl annotate ingress open-webui -n "${NAMESPACE}" cert-manager.io/cluster-issuer- 2>/dev/null || true
        
        # Delete Certificate resource if exists (we use manual certificates from GCS)
        if kubectl get certificate open-webui-tls -n "${NAMESPACE}" >/dev/null 2>&1; then
            echo "   Deleting cert-manager Certificate resource (using certificates from GCS)..."
            kubectl delete certificate open-webui-tls -n "${NAMESPACE}" --ignore-not-found=true
        fi
        
        # Load certificates from GCS bucket
        BACKUP_BUCKET="${BACKUP_BUCKET}" \
        "${PROJECT_ROOT}/scripts/create-self-signed-cert.sh" "${DOMAIN}" "${NAMESPACE}"
        echo "   ✓ Let's Encrypt certificates loaded from GCS bucket (cert-manager disabled)"
    else
        echo "   ⚠ Found certificates in GCS, but they are self-signed (not Let's Encrypt)"
        echo "   Using self-signed certificates from GCS..."
        BACKUP_BUCKET="${BACKUP_BUCKET}" \
        "${PROJECT_ROOT}/scripts/create-self-signed-cert.sh" "${DOMAIN}" "${NAMESPACE}"
        echo "   ✓ Self-signed certificates loaded from GCS bucket"
        echo "   Note: To use Let's Encrypt, upload Let's Encrypt certificates to gs://${BACKUP_BUCKET}/certs/"
    fi
else
    echo "   ⚠ No certificates found in GCS bucket"
    echo "   Generating self-signed certificates..."
    BACKUP_BUCKET="${BACKUP_BUCKET}" \
    "${PROJECT_ROOT}/scripts/create-self-signed-cert.sh" "${DOMAIN}" "${NAMESPACE}"
    echo "   ✓ Self-signed certificates generated and saved to GCS bucket"
    echo "   Note: cert-manager disabled. To use Let's Encrypt, upload Let's Encrypt certificates to gs://${BACKUP_BUCKET}/certs/"
fi
echo ""

# Step 5.5: Check if NFS provisioner is needed (optional - only if ReadWriteMany is required)
echo "Step 5.5: Checking storage requirements..."
DESIRED_ACCESS_MODE=$(grep "^[[:space:]]*accessMode:" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local" 2>/dev/null | head -1 | sed 's/.*accessMode:[[:space:]]*\([^#]*\).*/\1/' | tr -d '"' | tr -d ' ' || echo "ReadWriteOnce")
if [ "${DESIRED_ACCESS_MODE}" = "ReadWriteMany" ]; then
    echo "   ReadWriteMany detected - NFS provisioner may be needed"
    # Check if storage class exists and is working
    NFS_PROVISIONER_NEEDED=true
    if kubectl get storageclass nfs-client >/dev/null 2>&1; then
        # Check if NFS provisioner pod is actually running
        if kubectl get pods -n nfs-provisioner -l app=nfs-subdir-external-provisioner --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -q .; then
            echo "   NFS provisioner already installed and running (storage class 'nfs-client' exists)"
            NFS_PROVISIONER_NEEDED=false
        else
            echo "   Storage class 'nfs-client' exists but provisioner pod not running. Reinstalling..."
        fi
    fi

    if [ "$NFS_PROVISIONER_NEEDED" = "true" ]; then
        echo "   NFS provisioner not found or not working. Installing..."
        echo "   Note: This is normal when infrastructure is recreated (cluster was destroyed and recreated)"
        chmod +x "${PROJECT_ROOT}/scripts/install-nfs-provisioner.sh"
        "${PROJECT_ROOT}/scripts/install-nfs-provisioner.sh"
        echo "   NFS provisioner installed successfully"
    fi
else
    echo "   Using ReadWriteOnce - no NFS provisioner needed (standard GKE storage is sufficient)"
fi
echo ""

# Step 6: Create GCP Service Account Secret (for initContainer to access GCS)
echo "Step 6: Creating GCP Service Account secret for initContainer..."
if [ -n "${GCP_SA_KEY:-}" ]; then
    echo "   Creating Kubernetes secret with GCP Service Account key..."
    # Check if namespace exists, create if not
    if ! kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
        echo "   Creating namespace ${NAMESPACE}..."
        kubectl create namespace "${NAMESPACE}" || true
    fi
    # Create or update secret
    kubectl create secret generic gcp-sa-key \
        --from-literal=key.json="${GCP_SA_KEY}" \
        -n "${NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f - || true
    echo "    GCP Service Account secret created"
    GCP_SA_SECRET_NAME="gcp-sa-key"
else
    echo "     GCP_SA_KEY not set, initContainer will use default GCP credentials"
    echo "   (Workload Identity or node service account)"
    GCP_SA_SECRET_NAME=""
fi
echo ""

# Step 7: Prepare Helm values
echo "Step 7: Preparing Helm values..."
# Always create from example (never use existing local file in production)
# This ensures Git-based deployment uses only files from repository
rm -f "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
cp "${PROJECT_ROOT}/helm/open-webui/values.yaml.example" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"

# Get domain from environment variable (default to ai.svdevops.tech)
DOMAIN="${DOMAIN:-ai.svdevops.tech}"
echo "   Using domain: ${DOMAIN}"

# Replace domain in values.yaml.local with the one from environment variable
# This ensures the domain is always correct, even if values.yaml.example has a different domain
DOMAIN_ESCAPED=$(echo "${DOMAIN}" | sed 's/[[\.*^$()+?{|]/\\&/g')
sed -i.bak "s|^domain:.*|domain: ${DOMAIN}|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
sed -i.bak "s|^[[:space:]]*- host:.*|    - host: ${DOMAIN}|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
sed -i.bak "s|WEBUI_URL:.*|WEBUI_URL: \"https://${DOMAIN}\"|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
# Replace TLS hosts (more specific pattern)
sed -i.bak "s|^[[:space:]]*- ${DOMAIN_ESCAPED}|        - ${DOMAIN}|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
sed -i.bak "s|^[[:space:]]*- ai\\.svdevops\\.tech|        - ${DOMAIN}|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
sed -i.bak "s|^[[:space:]]*- ai-k8s\\.svdevops\\.tech|        - ${DOMAIN}|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"

WEBUI_SECRET_KEY=$(openssl rand -hex 32)
OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"

# Debug: Log API key status (without exposing full key)
if [ -n "${OPENROUTER_API_KEY}" ]; then
    echo "   ✓ OpenRouter API key received from environment"
    echo "   Key length: ${#OPENROUTER_API_KEY} characters"
    echo "   First 8 chars: ${OPENROUTER_API_KEY:0:8}..."
    echo "   Last 8 chars: ...${OPENROUTER_API_KEY: -8}"
    echo "   Using OpenRouter API key from environment"
    API_KEY_ESCAPED=$(echo "${OPENROUTER_API_KEY}" | sed 's/[[\.*^$()+?{|]/\\&/g')
    sed -i.bak "s|openrouterApiKey: \"\"|openrouterApiKey: \"${API_KEY_ESCAPED}\"|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
    echo "   ✓ API key written to values.yaml.local"
else
    echo "   ✗ OpenRouter API key NOT set (models may not work)"
    echo "   Set OPENROUTER_API_KEY environment variable to enable 344+ AI models"
fi

sed -i.bak "s|webuiSecretKey: \"\"|webuiSecretKey: \"${WEBUI_SECRET_KEY}\"|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"

# Enable backup restore via initContainer
sed -i.bak "s|restoreOnDeploy:.*|restoreOnDeploy: true|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
sed -i.bak "s|gcsBucket:.*|gcsBucket: \"${BACKUP_BUCKET}\"|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
if [ -n "${GCP_SA_SECRET_NAME}" ]; then
    sed -i.bak "s|gcpServiceAccount:.*|gcpServiceAccount: \"${GCP_SA_SECRET_NAME}\"|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
fi

rm -f "${PROJECT_ROOT}/helm/open-webui/values.yaml.local.bak"

echo "   Helm values prepared"
echo ""

# Step 8: Prepare namespace for Helm
echo "Step 8: Preparing namespace for Helm deployment..."
# Check if namespace exists
if kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "   Namespace already exists"
    # Check if namespace is managed by Helm
    MANAGED_BY=$(kubectl get namespace "${NAMESPACE}" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || echo "")
    if [ "$MANAGED_BY" = "Helm" ]; then
        echo "    Namespace is managed by Helm (OK)"
    else
        echo "     Namespace exists but not managed by Helm"
        echo "   Adding Helm metadata to namespace..."
        kubectl label namespace "${NAMESPACE}" app.kubernetes.io/managed-by=Helm --overwrite || true
        kubectl annotate namespace "${NAMESPACE}" meta.helm.sh/release-name=open-webui --overwrite || true
        kubectl annotate namespace "${NAMESPACE}" meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite || true
        echo "   Helm metadata added to namespace"
    fi
else
    echo "   Namespace does not exist (Helm will create it with --create-namespace)"
fi

# Step 9: Ensure application secret exists BEFORE Helm deploy (to avoid startup errors)
echo "Step 9: Ensuring application secret exists before Helm deploy..."
# Ensure base secret with WEBUI_SECRET_KEY
if ! kubectl get secret open-webui-secrets -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo "   Creating base secret open-webui-secrets with WEBUI_SECRET_KEY..."
    BASE_WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-$(openssl rand -hex 32)}"
    kubectl create secret generic open-webui-secrets \
        --from-literal=WEBUI_SECRET_KEY="${BASE_WEBUI_SECRET_KEY}" \
        -n "${NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f - || true
else
    echo "   Base secret open-webui-secrets already exists"
fi
# If OpenRouter key is provided, ensure OPENAI_* keys are present now
if [ -n "${OPENROUTER_API_KEY:-}" ]; then
    echo "   Setting OPENAI_API_KEY/OPENAI__API_KEY from OPENROUTER_API_KEY..."
    kubectl patch secret open-webui-secrets -n "${NAMESPACE}" \
      --type merge \
      -p "$(cat <<PATCH
{
  "stringData": {
    "OPENAI_API_KEY": "${OPENROUTER_API_KEY}",
    "OPENAI__API_KEY": "${OPENROUTER_API_KEY}"
  }
}
PATCH
)" || {
      echo "   Patch failed, creating secret from scratch..."
      kubectl create secret generic open-webui-secrets \
        --from-literal=OPENAI_API_KEY="${OPENROUTER_API_KEY}" \
        --from-literal=OPENAI__API_KEY="${OPENROUTER_API_KEY}" \
        -n "${NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f - || true
    }
    
    # Verify secret was updated
    SECRET_CHECK=$(kubectl get secret open-webui-secrets -n "${NAMESPACE}" -o jsonpath='{.data.OPENAI__API_KEY}' 2>/dev/null || echo "")
    if [ -n "${SECRET_CHECK}" ]; then
        echo "   ✓ Secret open-webui-secrets updated with OPENAI__API_KEY"
    else
        echo "   ✗ Warning: Could not verify secret update"
    fi
else
    echo "   OpenRouter API key not provided, skipping secret update"
fi

echo "   Ensuring Helm metadata on open-webui-secrets..."
kubectl label secret open-webui-secrets -n "${NAMESPACE}" app.kubernetes.io/managed-by=Helm --overwrite || true
kubectl annotate secret open-webui-secrets -n "${NAMESPACE}" meta.helm.sh/release-name=open-webui --overwrite || true
kubectl annotate secret open-webui-secrets -n "${NAMESPACE}" meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite || true
echo ""

# Step 10: Check and migrate PVC if access mode changed (RWO -> RWX)
echo "Step 10: Checking PVC access mode compatibility..."
# Find PVC by label (more reliable than hardcoded name)
PVC_NAME=$(kubectl get pvc -n "${NAMESPACE}" -l app.kubernetes.io/name=open-webui -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "${PVC_NAME}" ]; then
    # Fallback to standard naming convention
    PVC_NAME="open-webui-pvc"
fi
EXISTING_PVC_ACCESS_MODE=$(kubectl get pvc "${PVC_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null || echo "")
DESIRED_ACCESS_MODE=$(grep "^[[:space:]]*accessMode:" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local" | head -1 | sed 's/.*accessMode:[[:space:]]*\([^#]*\).*/\1/' | tr -d '"' | tr -d ' ' || echo "ReadWriteMany")
DESIRED_STORAGE_CLASS=$(grep "^[[:space:]]*storageClass:" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local" | head -1 | sed 's/.*storageClass:[[:space:]]*\([^#]*\).*/\1/' | tr -d '"' | tr -d ' ')
DESIRED_STORAGE_CLASS=${DESIRED_STORAGE_CLASS:-}
EXISTING_STORAGE_CLASS=$(kubectl get pvc "${PVC_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.storageClassName}' 2>/dev/null || echo "")

mismatch_reason=""
if [ -n "${EXISTING_PVC_ACCESS_MODE}" ] && [ "${EXISTING_PVC_ACCESS_MODE}" != "${DESIRED_ACCESS_MODE}" ]; then
    mismatch_reason="access mode mismatch (current: ${EXISTING_PVC_ACCESS_MODE}, desired: ${DESIRED_ACCESS_MODE})"
elif [ -n "${EXISTING_STORAGE_CLASS}" ] && [ -n "${DESIRED_STORAGE_CLASS}" ] && [ "${DESIRED_STORAGE_CLASS}" != "${EXISTING_STORAGE_CLASS}" ]; then
    mismatch_reason="storage class mismatch (current: ${EXISTING_STORAGE_CLASS}, desired: ${DESIRED_STORAGE_CLASS})"
fi

# Check if ReadWriteMany is requested and verify storage class compatibility
if [ "${DESIRED_ACCESS_MODE}" = "ReadWriteMany" ]; then
    if [ -z "${DESIRED_STORAGE_CLASS}" ] || [ "${DESIRED_STORAGE_CLASS}" = '""' ]; then
        DEFAULT_STORAGE_CLASS=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null || echo "")
        if [ -n "${DEFAULT_STORAGE_CLASS}" ]; then
            echo "   Warning: ReadWriteMany requested but using default storage class '${DEFAULT_STORAGE_CLASS}'"
            echo "   Standard GKE storage classes (standard, pd-standard, pd-ssd) do NOT support ReadWriteMany"
            echo "   NFS provisioner should be installed automatically in Step 5.5"
            echo "   If PVC creation fails, check if NFS provisioner is installed: kubectl get storageclass nfs-client"
        fi
    elif [ "${DESIRED_STORAGE_CLASS}" = "nfs-client" ]; then
        if ! kubectl get storageclass nfs-client >/dev/null 2>&1; then
            echo "   Warning: Storage class 'nfs-client' requested but not found"
            echo "   NFS provisioner should be installed automatically in Step 5.5"
            echo "   If this persists, run: ./scripts/install-nfs-provisioner.sh"
        else
            echo "   Using NFS provisioner storage class 'nfs-client' (supports ReadWriteMany)"
        fi
    fi
fi

if [ -n "${mismatch_reason}" ]; then
    migrate_pvc "existing spec differs from desired (${mismatch_reason})"
else
    if [ -n "${EXISTING_PVC_ACCESS_MODE}" ]; then
        echo "   PVC '${PVC_NAME}' exists with access mode '${EXISTING_PVC_ACCESS_MODE}' (matches desired mode '${DESIRED_ACCESS_MODE}')"
    else
        echo "   PVC does not exist yet (will be created by Helm with access mode '${DESIRED_ACCESS_MODE}')"
        echo "   Verifying storage class is configured correctly..."
        if [ -z "${DESIRED_STORAGE_CLASS}" ] || [ "${DESIRED_STORAGE_CLASS}" = '""' ]; then
            echo "   Warning: storageClass is empty in values.yaml.local"
            echo "   For ReadWriteMany, storageClass should be 'nfs-client'"
            echo "   Checking if NFS provisioner is available..."
            if kubectl get storageclass nfs-client >/dev/null 2>&1; then
                echo "   NFS storage class exists. PVC should be created correctly by Helm."
            else
                echo "   Error: NFS storage class not found. PVC creation may fail."
            fi
        fi
    fi
fi
echo ""

# Step 11: Deploy Open WebUI (with automatic backup restore via initContainer)
echo "Step 11: Deploying Open WebUI..."
echo "   Installing/upgrading Open WebUI via Helm..."
echo "   Note: Database will be automatically restored from backup via initContainer if enabled"

# Always use --create-namespace to ensure Helm manages the namespace
# If namespace exists, Helm will use it; if not, it will create it with proper metadata
echo "   Deploying with Helm (namespace will be created if needed)..."
echo "   Note: Deployment initiated, checking status..."

# Check if deployment exists and verify it's ready for rolling update
if kubectl get deployment open-webui -n "${NAMESPACE}" >/dev/null 2>&1; then
    CURRENT_REPLICAS=$(kubectl get deployment open-webui -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    echo "   Existing deployment found with ${CURRENT_REPLICAS} ready replicas"
    echo "   Using rolling update strategy (zero downtime deployment)"
    
    # Verify PVC supports ReadWriteMany for multiple replicas
    PVC_ACCESS_MODE=$(kubectl get pvc open-webui-pvc -n "${NAMESPACE}" -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null || echo "")
    if [ "${PVC_ACCESS_MODE}" != "ReadWriteMany" ] && [ "${CURRENT_REPLICAS}" -gt 1 ]; then
        echo "   Warning: PVC access mode is '${PVC_ACCESS_MODE}' but ${CURRENT_REPLICAS} replicas exist"
        echo "   Rolling update may fail with ReadWriteOnce PVC. Consider migrating to ReadWriteMany."
    fi
fi

# Try to install/upgrade with retry logic
MAX_RETRIES=3
RETRY_COUNT=0
PVC_HELM_RETRY=false
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if helm upgrade --install open-webui "${PROJECT_ROOT}/helm/open-webui" \
        -n "${NAMESPACE}" \
        -f "${PROJECT_ROOT}/helm/open-webui/values.yaml.local" \
        --create-namespace \
        --timeout 10m \
        --wait \
        --wait-for-jobs 2>&1 | tee /tmp/helm-webui-output.log; then
        echo "   Open WebUI deployed successfully"
        break
    else
        if grep -q "PersistentVolumeClaim .*spec: Forbidden" /tmp/helm-webui-output.log 2>/dev/null; then
            if [ "${PVC_HELM_RETRY}" = "true" ]; then
                echo "   Error: PVC immutable spec issue persists after retry"
                cat /tmp/helm-webui-output.log
                exit 1
            fi
            PVC_HELM_RETRY=true
            echo "   Detected immutable PVC spec error from Helm output"
            migrate_pvc "Helm reported immutable PVC spec mismatch"
            echo "   Retrying Helm deployment after recreating PVC..."
            continue
        fi
        if grep -q "another operation.*is in progress" /tmp/helm-webui-output.log 2>/dev/null; then
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "   Warning: Detected pending Helm operation (attempt ${RETRY_COUNT}/${MAX_RETRIES})"
            clear_helm_pending "open-webui" "${NAMESPACE}"
            echo "   Retrying deployment..."
            sleep 5
        else
            echo "   Error: Helm deployment failed with different error"
            cat /tmp/helm-webui-output.log
            exit 1
        fi
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "   Error: Failed to deploy Open WebUI after ${MAX_RETRIES} attempts"
    exit 1
fi

echo "    Helm deployment command completed"
echo ""

# Step 11.5: Force rolling update by restarting deployment (ensures new pod is created)
# This works around Helm not always detecting pod template changes
echo "Step 11.5: Forcing rolling update to ensure new pod is created..."
if kubectl rollout restart deployment/open-webui -n "${NAMESPACE}" 2>/dev/null; then
    echo "    Deployment restart initiated for zero-downtime rolling update"
else
    echo "    Warning: Failed to restart deployment (may already be in progress)"
fi
echo ""

# Step 12: Ensure required secrets exist (fallback for chart issues) — kept as safety
echo "Step 12: Ensuring required secrets exist (post-deploy safety)..."
kubectl get secret open-webui-secrets -n "${NAMESPACE}" >/dev/null 2>&1 || {
  echo "   Secret unexpectedly missing; creating fallback..."
  FALLBACK_WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-$(openssl rand -hex 32)}"
  kubectl create secret generic open-webui-secrets \
      --from-literal=WEBUI_SECRET_KEY="${FALLBACK_WEBUI_SECRET_KEY}" \
      -n "${NAMESPACE}" \
      --dry-run=client -o yaml | kubectl apply -f - || true
}
if [ -n "${OPENROUTER_API_KEY:-}" ]; then
  kubectl patch secret open-webui-secrets -n "${NAMESPACE}" --type merge -p "$(cat <<PATCH
{
  "stringData": {
    "OPENAI_API_KEY": "${OPENROUTER_API_KEY}",
    "OPENAI__API_KEY": "${OPENROUTER_API_KEY}"
  }
}
PATCH
)" || true
fi
echo ""

# Step 13: Ensure HPA is disabled (if needed)
echo "Step 13: Checking HPA configuration..."
if kubectl get hpa open-webui -n "${NAMESPACE}" 2>/dev/null; then
    echo "   HPA found, checking if it should be disabled..."
    # HPA can be left enabled if configured in values.yaml
else
    echo "   HPA not found (OK, using fixed replica count from values.yaml)"
fi
echo ""

# Step 14: Check pod status and ensure rollout completed
echo "Step 14: Checking pod status and rollout completion..."
echo "   Waiting for rollout to complete (with timeout)..."
if kubectl rollout status deployment/open-webui -n "${NAMESPACE}" --timeout=300s 2>/dev/null; then
    echo "    Rollout completed successfully"
    
    # Verify all pods are from the new ReplicaSet
    NEW_RS=$(kubectl get deployment open-webui -n "${NAMESPACE}" -o jsonpath='{.status.observedGeneration}' 2>/dev/null || echo "0")
    ACTUAL_REPLICAS=$(kubectl get deployment open-webui -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED_REPLICAS=$(kubectl get deployment open-webui -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    
    echo "   Desired replicas: ${DESIRED_REPLICAS}, Ready replicas: ${ACTUAL_REPLICAS}"
    
    # Check for old ReplicaSets
    OLD_RS_COUNT=$(kubectl get replicasets -n "${NAMESPACE}" -l app.kubernetes.io/name=open-webui --no-headers 2>/dev/null | awk '$2+$3+$4 > 0 {count++} END {print count+0}')
    if [ "${OLD_RS_COUNT}" -gt 1 ]; then
        echo "   Warning: Multiple ReplicaSets detected. Old pods may still be running."
        kubectl get replicasets -n "${NAMESPACE}" -l app.kubernetes.io/name=open-webui
        echo "   Cleaning up old ReplicaSets..."
        kubectl delete replicaset -n "${NAMESPACE}" -l app.kubernetes.io/name=open-webui --field-selector=status.replicas=0 2>/dev/null || true
    fi
    
    if [ "${ACTUAL_REPLICAS}" != "${DESIRED_REPLICAS}" ]; then
        echo "   Warning: Replica count mismatch! Desired: ${DESIRED_REPLICAS}, Ready: ${ACTUAL_REPLICAS}"
        echo "   Checking pod status..."
        kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=open-webui
    fi
else
    echo "    Rollout did not complete within timeout. Checking status..."
    kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=open-webui
    kubectl describe deploy/open-webui -n "${NAMESPACE}" || true
    kubectl get events -n "${NAMESPACE}" --sort-by=.lastTimestamp | tail -n 50 || true
fi
echo ""

# Step 15: Verify database restore (restore happens automatically via initContainer)
echo "Step 15: Verifying database restore..."
echo "   Note: Database restore happens automatically via initContainer during pod startup"
echo "   Checking if database was restored..."

# Wait a bit for initContainer to complete
sleep 5

POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name="${APP_NAME}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "${POD_NAME}" ]; then
    echo "   Checking initContainer logs..."
    kubectl logs -n "${NAMESPACE}" "${POD_NAME}" -c restore-database 2>/dev/null || echo "   (initContainer logs not available yet)"
    
    echo "   Waiting for pod to be ready..."
    kubectl wait --for=condition=Ready pod -n "${NAMESPACE}" "${POD_NAME}" --timeout=300s || true
    
    echo "   Checking restored users..."
    sleep 5
    kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- python3 -c "import sqlite3; conn = sqlite3.connect('/app/backend/data/webui.db'); cursor = conn.cursor(); cursor.execute('SELECT email, role FROM user;'); users = cursor.fetchall(); print(f'   Найдено пользователей: {len(users)}'); [print(f'     - {u[0]} ({u[1]})') for u in users]" 2>/dev/null || echo "   (проверка пользователей...)"
else
    echo "     Pod not found yet, restore will happen when pod starts"
fi

echo ""
echo "Deployment completed successfully!"
echo ""
echo " Status:"
kubectl get pods -n "${NAMESPACE}"
echo ""
kubectl get ingress -n "${NAMESPACE}"
echo ""
echo " Domain: https://ai.svdevops.tech"
echo " IP: ${INGRESS_IP}"

