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
        image: itsthenetwork/nfs-server-alpine:latest
        env:
        - name: SHARED_DIRECTORY
          value: /exports
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
  type: ClusterIP
EOF

echo "   NFS server deployment created"
echo "   Waiting for NFS server to be ready (this may take 1-2 minutes)..."
echo "   Monitoring NFS server pod status..."
# Show initial pod status
kubectl get pods -n "${NFS_SERVER_NAMESPACE}" || true
echo ""

if kubectl wait --for=condition=available --timeout=180s deployment/nfs-server -n "${NFS_SERVER_NAMESPACE}" 2>/dev/null; then
    echo "   NFS server is ready"
else
    echo "   Warning: NFS server may still be starting. Checking status..."
    kubectl get pods -n "${NFS_SERVER_NAMESPACE}" || true
    echo "   Checking pod events:"
    kubectl get events -n "${NFS_SERVER_NAMESPACE}" --sort-by=.lastTimestamp | tail -5 || true
    echo "   Continuing anyway (will retry getting IP)..."
fi
echo ""

# Step 3: Get NFS server IP (use pod IP directly for reliability)
echo "Step 3: Getting NFS server IP..."
echo "   Waiting for NFS server pod to be ready..."
MAX_RETRIES=12
RETRY_COUNT=0
NFS_SERVER_IP=""
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    sleep 5
    # Get pod IP directly (more reliable than service IP)
    NFS_SERVER_IP=$(kubectl get pods -n "${NFS_SERVER_NAMESPACE}" -l app=nfs-server -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || echo "")
    if [ -z "${NFS_SERVER_IP}" ] || [ "${NFS_SERVER_IP}" = "None" ]; then
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "   Waiting for NFS server pod IP... (attempt ${RETRY_COUNT}/${MAX_RETRIES})"
    else
        break
    fi
done

if [ -z "${NFS_SERVER_IP}" ] || [ "${NFS_SERVER_IP}" = "None" ]; then
    echo "   Error: NFS server IP not available after ${MAX_RETRIES} attempts"
    echo "   Checking NFS server status..."
    kubectl get pods -n "${NFS_SERVER_NAMESPACE}" || true
    kubectl get events -n "${NFS_SERVER_NAMESPACE}" --sort-by=.lastTimestamp | tail -10 || true
    exit 1
fi

echo "   NFS server IP: ${NFS_SERVER_IP} (using pod IP directly)"
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
echo "   This may take 2-5 minutes (downloading images, creating pods)..."
# Remove existing release if it exists but is broken (e.g., after cluster recreation)
if helm list -n "${NAMESPACE}" 2>/dev/null | grep -q nfs-subdir-external-provisioner; then
    echo "   Existing Helm release found. Upgrading..."
else
    echo "   Installing new Helm release..."
fi

# Install with progress output
echo "   Running helm install (this may take a few minutes)..."
echo "   NFS server IP: ${NFS_SERVER_IP}"

# Install without --wait to avoid timeout issues, then check status manually
echo "   Installing Helm chart (without waiting for pods to be ready)..."
echo "   Using NFS server IP: ${NFS_SERVER_IP}"

# Delete existing release if stuck
if helm list -n "${NAMESPACE}" 2>/dev/null | grep -q nfs-subdir-external-provisioner; then
    echo "   Existing release found, upgrading..."
    # Try to delete stuck secrets first
    kubectl get secrets -n "${NAMESPACE}" -l owner=helm 2>/dev/null | grep "sh.helm.release.v1.nfs-subdir" | grep -v "deployed" | awk '{print $1}' | xargs -r -I {} kubectl delete secret {} -n "${NAMESPACE}" 2>/dev/null || true
    sleep 2
fi

if helm upgrade --install nfs-subdir-external-provisioner \
    nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --namespace "${NAMESPACE}" \
    --set nfs.server="${NFS_SERVER_IP}" \
    --set nfs.path=/ \
    --set storageClass.name=nfs-client \
    --set storageClass.defaultClass=false \
    --set storageClass.accessModes=ReadWriteMany \
    --timeout 5m 2>&1; then
    echo "   Helm chart installed successfully"
else
    echo "   Warning: Helm install had issues, but continuing to check status..."
    # Don't exit - let's check if resources were created anyway
fi

echo ""
echo "   Waiting for NFS provisioner deployment to be created..."
sleep 5

# Wait for deployment to be available
MAX_WAIT=360  # 6 minutes
WAIT_COUNT=0
DEPLOYMENT_READY=false

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if kubectl get deployment nfs-subdir-external-provisioner -n "${NAMESPACE}" >/dev/null 2>&1; then
        READY=$(kubectl get deployment nfs-subdir-external-provisioner -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        DESIRED=$(kubectl get deployment nfs-subdir-external-provisioner -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        if [ "${READY}" = "${DESIRED}" ] && [ "${READY}" != "0" ]; then
            echo "   ✓ NFS provisioner pods are ready! (${READY}/${DESIRED})"
            DEPLOYMENT_READY=true
            break
        else
            if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
                echo "   Waiting for NFS provisioner pods... (${READY}/${DESIRED} ready, ${WAIT_COUNT}s/${MAX_WAIT}s)"
                kubectl get pods -n "${NAMESPACE}" -l app=nfs-subdir-external-provisioner || true
            fi
        fi
    else
        if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
            echo "   Waiting for deployment to be created... (${WAIT_COUNT}s/${MAX_WAIT}s)"
        fi
    fi
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 5))
done

if [ "$DEPLOYMENT_READY" = "false" ]; then
    echo "   ⚠ Warning: NFS provisioner pods not ready after ${MAX_WAIT}s"
    echo "   Checking current status..."
    kubectl get pods -n "${NAMESPACE}" -l app=nfs-subdir-external-provisioner || true
    echo ""
    echo "   Checking pod events:"
    kubectl get events -n "${NAMESPACE}" --sort-by=.lastTimestamp | tail -10 || true
    echo ""
    echo "   Checking if storage class was created anyway..."
    if kubectl get storageclass nfs-client >/dev/null 2>&1; then
        echo "   ✓ Storage class 'nfs-client' exists - installation may still work"
        echo "   Continuing (pods may start later)..."
    else
        echo "   ✗ Storage class not found - installation may have failed"
        echo "   But continuing anyway - it may still work..."
    fi
fi

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

