#!/bin/bash
# Simplified deployment script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

# Configuration
NAMESPACE="${NAMESPACE:-ai}"
DOMAIN="${DOMAIN:-ai.svdevops.tech}"
BACKUP_BUCKET="${BACKUP_BUCKET:-open-webui-backups}"
GCP_PROJECT_ID="${GCP_PROJECT_ID:-${TF_VAR_project_id:-ai-cluster-478022}}"
GCP_REGION="${GCP_REGION:-${TF_VAR_region:-europe-west1}}"
GCP_ZONE="${GCP_ZONE:-${TF_VAR_zone:-europe-west1-b}}"
CLUSTER_NAME="${CLUSTER_NAME:-${TF_VAR_cluster_name:-open-webui-cluster}}"

echo "=== Deploying Open WebUI to Kubernetes ==="
echo "Cluster: ${CLUSTER_NAME}"
echo "Namespace: ${NAMESPACE}"
echo "Domain: ${DOMAIN}"
echo ""

# Step 1: Get cluster credentials
echo "Step 1: Getting cluster credentials..."
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --zone "${GCP_ZONE}" \
    --project "${GCP_PROJECT_ID}" || exit 1
kubectl cluster-info || exit 1
echo ""

# Step 2: Get static IP
echo "Step 2: Getting static IP address..."
cd "${PROJECT_ROOT}/terraform"
INGRESS_IP=$(TF_VAR_project_id="${GCP_PROJECT_ID}" \
  TF_VAR_region="${GCP_REGION}" \
  TF_VAR_zone="${GCP_ZONE}" \
  TF_VAR_cluster_name="${CLUSTER_NAME}" \
  terraform output -raw ingress_ip 2>/dev/null || \
  gcloud compute addresses describe "${CLUSTER_NAME}-ingress-ip" \
    --region="${GCP_REGION}" \
    --project="${GCP_PROJECT_ID}" \
    --format="value(address)" 2>/dev/null || echo "")

if [ -z "${INGRESS_IP}" ]; then
    echo "Error: Could not find static IP address"
    exit 1
fi
echo "Static IP: ${INGRESS_IP}"
cd "${PROJECT_ROOT}"
echo ""

# Step 3: Install/Upgrade NGINX Ingress
echo "Step 3: Installing NGINX Ingress..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update >/dev/null 2>&1

if helm list -n ingress-nginx --filter ingress-nginx -q >/dev/null 2>&1; then
    echo "NGINX Ingress already installed, upgrading..."
    helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --reuse-values \
        --set controller.service.loadBalancerIP="${INGRESS_IP}" \
        --wait >/dev/null 2>&1 || true
else
    echo "Installing NGINX Ingress..."
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --set controller.service.annotations."cloud\.google\.com/load-balancer-type"="External" \
        --set controller.service.loadBalancerIP="${INGRESS_IP}" \
        --wait >/dev/null 2>&1 || true
fi
echo ""

# Step 4: Load SSL certificates
echo "Step 4: Loading SSL certificates from GCS..."
GCS_CERT_FILE="gs://${BACKUP_BUCKET}/certs/${DOMAIN}.crt"
GCS_KEY_FILE="gs://${BACKUP_BUCKET}/certs/${DOMAIN}.key"

if gsutil -q stat "${GCS_CERT_FILE}" 2>/dev/null && gsutil -q stat "${GCS_KEY_FILE}" 2>/dev/null; then
    echo "Certificates found in GCS, loading..."
    BACKUP_BUCKET="${BACKUP_BUCKET}" \
    "${PROJECT_ROOT}/scripts/create-self-signed-cert.sh" "${DOMAIN}" "${NAMESPACE}" >/dev/null 2>&1 || true
else
    echo "No certificates found, generating self-signed..."
    BACKUP_BUCKET="${BACKUP_BUCKET}" \
    "${PROJECT_ROOT}/scripts/create-self-signed-cert.sh" "${DOMAIN}" "${NAMESPACE}" >/dev/null 2>&1 || true
fi

# Remove cert-manager annotation if exists
kubectl annotate ingress open-webui -n "${NAMESPACE}" cert-manager.io/cluster-issuer- 2>/dev/null || true
kubectl delete certificate open-webui-tls -n "${NAMESPACE}" --ignore-not-found=true 2>/dev/null || true
echo ""

# Step 5: Install NFS provisioner if needed
echo "Step 5: Checking storage requirements..."
if grep -q "accessMode:.*ReadWriteMany" "${PROJECT_ROOT}/helm/open-webui/values.yaml.example" 2>/dev/null; then
    if ! kubectl get storageclass nfs-client >/dev/null 2>&1 || \
       ! kubectl get pods -n nfs-provisioner -l app=nfs-subdir-external-provisioner --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -q .; then
        echo "Installing NFS provisioner..."
        chmod +x "${PROJECT_ROOT}/scripts/install-nfs-provisioner.sh"
        "${PROJECT_ROOT}/scripts/install-nfs-provisioner.sh" >/dev/null 2>&1 || true
    fi
fi
echo ""

# Step 6: Create namespace and secrets
echo "Step 6: Preparing namespace and secrets..."
kubectl create namespace "${NAMESPACE}" 2>/dev/null || true

# Ensure namespace has Helm metadata (required for Helm to manage it)
echo "   Ensuring Helm metadata on namespace..."
kubectl label namespace "${NAMESPACE}" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
kubectl annotate namespace "${NAMESPACE}" meta.helm.sh/release-name=open-webui --overwrite 2>/dev/null || true
kubectl annotate namespace "${NAMESPACE}" meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite 2>/dev/null || true

# Create GCP SA secret if provided
if [ -n "${GCP_SA_KEY:-}" ]; then
    kubectl create secret generic gcp-sa-key \
        --from-literal=key.json="${GCP_SA_KEY}" \
        -n "${NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
    GCP_SA_SECRET_NAME="gcp-sa-key"
else
    GCP_SA_SECRET_NAME=""
fi

# Create app secrets
WEBUI_SECRET_KEY=$(openssl rand -hex 32)
if ! kubectl get secret open-webui-secrets -n "${NAMESPACE}" >/dev/null 2>&1; then
    kubectl create secret generic open-webui-secrets \
        --from-literal=WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY}" \
        -n "${NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
fi

if [ -n "${OPENROUTER_API_KEY:-}" ]; then
    kubectl patch secret open-webui-secrets -n "${NAMESPACE}" --type merge -p "{
        \"stringData\": {
            \"OPENAI_API_KEY\": \"${OPENROUTER_API_KEY}\",
            \"OPENAI__API_KEY\": \"${OPENROUTER_API_KEY}\"
        }
    }" >/dev/null 2>&1 || {
        kubectl create secret generic open-webui-secrets \
            --from-literal=OPENAI_API_KEY="${OPENROUTER_API_KEY}" \
            --from-literal=OPENAI__API_KEY="${OPENROUTER_API_KEY}" \
            -n "${NAMESPACE}" \
            --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
    }
fi
echo ""

# Step 7: Prepare Helm values
echo "Step 7: Preparing Helm values..."
rm -f "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
cp "${PROJECT_ROOT}/helm/open-webui/values.yaml.example" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"

DOMAIN_ESCAPED=$(echo "${DOMAIN}" | sed 's/[[\.*^$()+?{|]/\\&/g')
sed -i.bak "s|^domain:.*|domain: ${DOMAIN}|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
sed -i.bak "s|^[[:space:]]*- host:.*|    - host: ${DOMAIN}|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
sed -i.bak "s|WEBUI_URL:.*|WEBUI_URL: \"https://${DOMAIN}\"|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
sed -i.bak "s|^[[:space:]]*- ai\\.svdevops\\.tech|        - ${DOMAIN}|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
sed -i.bak "s|^[[:space:]]*- ai-k8s\\.svdevops\\.tech|        - ${DOMAIN}|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"

sed -i.bak "s|webuiSecretKey: \"\"|webuiSecretKey: \"${WEBUI_SECRET_KEY}\"|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
sed -i.bak "s|restoreOnDeploy:.*|restoreOnDeploy: true|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
sed -i.bak "s|gcsBucket:.*|gcsBucket: \"${BACKUP_BUCKET}\"|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"

if [ -n "${OPENROUTER_API_KEY:-}" ]; then
    API_KEY_ESCAPED=$(echo "${OPENROUTER_API_KEY}" | sed 's/[[\.*^$()+?{|]/\\&/g')
    sed -i.bak "s|openrouterApiKey: \"\"|openrouterApiKey: \"${API_KEY_ESCAPED}\"|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
fi

if [ -n "${GCP_SA_SECRET_NAME}" ]; then
    sed -i.bak "s|gcpServiceAccount:.*|gcpServiceAccount: \"${GCP_SA_SECRET_NAME}\"|g" "${PROJECT_ROOT}/helm/open-webui/values.yaml.local"
fi

rm -f "${PROJECT_ROOT}/helm/open-webui/values.yaml.local.bak"
echo ""

# Step 8: Deploy with Helm
echo "Step 8: Deploying Open WebUI..."
helm upgrade --install open-webui "${PROJECT_ROOT}/helm/open-webui" \
    -n "${NAMESPACE}" \
    -f "${PROJECT_ROOT}/helm/open-webui/values.yaml.local" \
    --create-namespace \
    --timeout 10m \
    --wait || {
    echo "Warning: Helm deployment failed or timed out"
    echo "Checking status..."
    kubectl get pods -n "${NAMESPACE}" || true
    exit 1
}
echo ""

# Step 9: Wait for pods to be ready
echo "Step 9: Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod -n "${NAMESPACE}" -l app.kubernetes.io/name=open-webui --timeout=600s || {
    echo "Warning: Pods not ready after timeout"
    echo "Pod status:"
    kubectl get pods -n "${NAMESPACE}" || true
    echo "Pod logs:"
    POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=open-webui -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "${POD_NAME}" ]; then
        kubectl logs -n "${NAMESPACE}" "${POD_NAME}" --tail=50 || true
    fi
    exit 1
}

# Step 10: Verify rollout
echo "Step 10: Verifying deployment..."
kubectl rollout status deployment/open-webui -n "${NAMESPACE}" --timeout=300s || {
    echo "Warning: Rollout not complete"
    kubectl get deployment -n "${NAMESPACE}" || true
}

echo ""
echo "=== Deployment completed successfully! ==="
echo ""
kubectl get pods -n "${NAMESPACE}"
echo ""
kubectl get ingress -n "${NAMESPACE}"
echo ""
echo "Domain: https://${DOMAIN}"
echo "IP: ${INGRESS_IP}"
