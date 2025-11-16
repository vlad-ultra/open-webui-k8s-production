#!/bin/bash
# Script to install NFS provisioner for ReadWriteMany (RWX) storage support
# This allows multiple pods to mount the same volume simultaneously

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

NAMESPACE="nfs-provisioner"
NFS_SERVER_NAMESPACE="nfs-server"
STORAGE_SIZE="20Gi"  # Size for NFS server storage

echo "=== Installing NFS Provisioner for ReadWriteMany Support ==="
echo ""

# Step 1: Create namespace for NFS server
echo "Step 1: Creating namespace for NFS server..."
kubectl create namespace "${NFS_SERVER_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
echo "   Namespace '${NFS_SERVER_NAMESPACE}' ready"
echo ""

# Step 2: Deploy NFS server
echo "Step 2: Deploying NFS server..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-server-pvc
  namespace: ${NFS_SERVER_NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${STORAGE_SIZE}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-server
  namespace: ${NFS_SERVER_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfs-server
  template:
    metadata:
      labels:
        app: nfs-server
    spec:
      containers:
      - name: nfs-server
        image: gcr.io/google-samples/nfs-server:1.0
        ports:
        - name: nfs
          containerPort: 2049
        - name: mountd
          containerPort: 20048
        - name: rpcbind
          containerPort: 111
        securityContext:
          privileged: true
        volumeMounts:
        - mountPath: /exports
          name: nfs-pvc
      volumes:
      - name: nfs-pvc
        persistentVolumeClaim:
          claimName: nfs-server-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: nfs-server
  namespace: ${NFS_SERVER_NAMESPACE}
spec:
  ports:
  - name: nfs
    port: 2049
  - name: mountd
    port: 20048
  - name: rpcbind
    port: 111
  selector:
    app: nfs-server
  clusterIP: None  # Headless service
EOF

echo "   NFS server deployment created"
echo "   Waiting for NFS server to be ready..."
if kubectl wait --for=condition=available --timeout=180s deployment/nfs-server -n "${NFS_SERVER_NAMESPACE}" 2>/dev/null; then
    echo "   NFS server is ready"
else
    echo "   Warning: NFS server may still be starting. Checking status..."
    kubectl get pods -n "${NFS_SERVER_NAMESPACE}" || true
    echo "   Continuing anyway..."
fi
echo ""

# Step 3: Get NFS server service IP
echo "Step 3: Getting NFS server service IP..."
echo "   Waiting for NFS server service to be available..."
MAX_RETRIES=12
RETRY_COUNT=0
NFS_SERVER_IP=""
while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ -z "${NFS_SERVER_IP}" ]; do
    sleep 5
    NFS_SERVER_IP=$(kubectl get svc nfs-server -n "${NFS_SERVER_NAMESPACE}" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
    if [ -z "${NFS_SERVER_IP}" ]; then
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "   Waiting for NFS server service IP... (attempt ${RETRY_COUNT}/${MAX_RETRIES})"
    fi
done

if [ -z "${NFS_SERVER_IP}" ]; then
    echo "   Error: NFS server IP not available after ${MAX_RETRIES} attempts"
    echo "   Checking NFS server status..."
    kubectl get svc -n "${NFS_SERVER_NAMESPACE}" || true
    kubectl get pods -n "${NFS_SERVER_NAMESPACE}" || true
    exit 1
fi

echo "   NFS server IP: ${NFS_SERVER_IP}"
echo ""

# Step 4: Add Helm repository for NFS provisioner
echo "Step 4: Adding Helm repository for NFS provisioner..."
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/ 2>/dev/null || echo "   Repository already exists"
helm repo update
echo ""

# Step 5: Create namespace for NFS provisioner
echo "Step 5: Creating namespace for NFS provisioner..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
echo "   Namespace '${NAMESPACE}' ready"
echo ""

# Step 6: Install NFS provisioner
echo "Step 6: Installing NFS subdir external provisioner..."
# Remove existing release if it exists but is broken (e.g., after cluster recreation)
if helm list -n "${NAMESPACE}" 2>/dev/null | grep -q nfs-subdir-external-provisioner; then
    echo "   Existing Helm release found. Upgrading..."
else
    echo "   Installing new Helm release..."
fi

helm upgrade --install nfs-subdir-external-provisioner \
    nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --namespace "${NAMESPACE}" \
    --set nfs.server="${NFS_SERVER_IP}" \
    --set nfs.path=/ \
    --set storageClass.name=nfs-client \
    --set storageClass.defaultClass=false \
    --set storageClass.accessModes=ReadWriteMany \
    --wait \
    --timeout 5m

echo "   NFS provisioner installed"
echo ""

# Step 7: Verify installation
echo "Step 7: Verifying installation..."
sleep 5
if kubectl get storageclass nfs-client >/dev/null 2>&1; then
    echo "   Storage class 'nfs-client' created successfully"
    kubectl get storageclass nfs-client
else
    echo "   Warning: Storage class 'nfs-client' not found. Installation may have failed."
    exit 1
fi

echo ""
echo "=== NFS Provisioner Installation Complete ==="
echo ""
echo "Storage class 'nfs-client' is now available and supports ReadWriteMany (RWX)"
echo "You can now use it in your PVCs by setting:"
echo "  storageClass: nfs-client"
echo "  accessMode: ReadWriteMany"
echo ""
echo "To verify, run:"
echo "  kubectl get storageclass"
echo "  kubectl get pods -n ${NAMESPACE}"
echo "  kubectl get pods -n ${NFS_SERVER_NAMESPACE}"

