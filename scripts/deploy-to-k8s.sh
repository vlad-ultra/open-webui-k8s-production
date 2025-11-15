#!/bin/bash
# Script to deploy application to Kubernetes
# Usage: ./scripts/deploy-to-k8s.sh
# 
# Prerequisites: Infrastructure must be deployed first with ./scripts/deploy-infra.sh
# 
# This script will:
# 1. Get cluster credentials
# 2. Install NGINX Ingress with static IP
# 3. Install cert-manager
# 4. Deploy Open WebUI via Helm
# 5. Restore database from backup (if exists)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

NAMESPACE="ai"
APP_NAME="open-webui"
BACKUP_BUCKET="open-webui-backups"
DOMAIN="${DOMAIN:-ai-k8s.svdevops.tech}"
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

gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --zone "${GCP_ZONE}" \
    --project "${GCP_PROJECT_ID}"

echo "   Credentials configured"
echo ""

# Step 2: Check cluster status
echo "Step 2: Checking cluster status..."
kubectl cluster-info
echo "   Cluster credentials configured"
echo ""

# Step 3: Get static IP from terraform or GCP
echo "📍 Step 3: Getting static IP address..."
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

echo "   Installing NGINX Ingress with static IP: ${INGRESS_IP}..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.service.type=LoadBalancer \
    --set controller.service.annotations."cloud\.google\.com/load-balancer-type"="External" \
    --set controller.service.loadBalancerIP="${INGRESS_IP}" \
    --wait

echo "    NGINX Ingress installed with IP: ${INGRESS_IP}"
echo ""

# Step 5: Install cert-manager and create SSL certificate
echo "Step 5: Installing cert-manager and setting up SSL certificate..."
echo "   Applying cert-manager manifests..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
echo "   Waiting for cert-manager pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
echo "   Applying cluster issuer..."
kubectl apply -f "${PROJECT_ROOT}/bootstrap/cluster-issuer.yaml"

# Check if TLS secret exists, if not create self-signed certificate from GCS bucket or local files
if ! kubectl get secret "${SECRET_NAME:-open-webui-tls}" -n "${NAMESPACE}" > /dev/null 2>&1; then
    echo "   TLS secret not found, creating from GCS bucket or local certificates..."
    DOMAIN="${DOMAIN:-ai-k8s.svdevops.tech}"
    BACKUP_BUCKET="${BACKUP_BUCKET:-open-webui-backups}"
    BACKUP_BUCKET="${BACKUP_BUCKET}" \
    "${PROJECT_ROOT}/scripts/create-self-signed-cert.sh" "${DOMAIN}" "${NAMESPACE}"
else
    echo "   TLS secret already exists in Kubernetes, skipping certificate creation"
fi

echo "   ✅ cert-manager installed and SSL certificate ready"
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

WEBUI_SECRET_KEY=$(openssl rand -hex 32)
OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"

if [ -n "${OPENROUTER_API_KEY}" ]; then
    echo "   Using OpenRouter API key from environment"
    API_KEY_ESCAPED=$(echo "${OPENROUTER_API_KEY}" | sed 's/[[\.*^$()+?{|]/\\&/g')
    sed -i.bak "s|openrouterApiKey: \"\"|openrouterApiKey: \"${API_KEY_ESCAPED}\"|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
else
    echo "    OpenRouter API key not set (models may not work)"
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

# Step 9: Deploy Open WebUI (with automatic backup restore via initContainer)
echo "Step 9: Deploying Open WebUI..."
echo "   Installing/upgrading Open WebUI via Helm..."
echo "   Note: Database will be automatically restored from backup via initContainer if enabled"

# Always use --create-namespace to ensure Helm manages the namespace
# If namespace exists, Helm will use it; if not, it will create it with proper metadata
echo "   Deploying with Helm (namespace will be created if needed)..."
echo "   Note: Deployment initiated, checking status..."
helm upgrade --install open-webui "${PROJECT_ROOT}/helm/open-webui" \
    -n "${NAMESPACE}" \
    -f "${PROJECT_ROOT}/helm/open-webui/values.yaml.local" \
    --create-namespace \
    --timeout 5m

echo "    Helm deployment command completed"
echo ""

# Step 10: Ensure only 1 replica and no HPA (do this quickly, don't wait)
echo "Step 10: Ensuring single pod configuration..."
echo "   Checking for HPA..."
if kubectl get hpa open-webui -n "${NAMESPACE}" 2>/dev/null; then
    echo "   Deleting HPA (autoscaling disabled)..."
    kubectl delete hpa open-webui -n "${NAMESPACE}" 2>/dev/null || true
else
    echo "   HPA not found (OK)"
fi
echo "   Setting deployment to 1 replica..."
kubectl scale deployment open-webui -n "${NAMESPACE}" --replicas=1 2>/dev/null || echo "   (Deployment may not be ready yet, will be set on next check)"
echo "    Single pod configuration ensured"
echo ""

# Step 11: Check pod status (non-blocking)
echo "Step 11: Checking pod status..."
echo "   Waiting for pod to be ready (with timeout)..."
if kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=open-webui -n "${NAMESPACE}" --timeout=60s 2>/dev/null; then
    echo "    Pod is ready"
else
    echo "    Pod is still starting (this is normal, it may take a few minutes)"
    echo "   You can check status with: kubectl get pods -n ${NAMESPACE}"
fi
echo ""

# Step 12: Verify database restore (restore happens automatically via initContainer)
echo "Step 12: Verifying database restore..."
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
echo " Domain: https://ai-k8s.svdevops.tech"
echo " IP: ${INGRESS_IP}"

