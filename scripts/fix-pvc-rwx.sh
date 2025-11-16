#!/bin/bash
# Quick fix script to migrate PVC from ReadWriteOnce to ReadWriteMany
# This will delete the old PVC and allow Helm to create a new one with RWX

set -e

NAMESPACE="${NAMESPACE:-ai}"
PVC_NAME="${PVC_NAME:-open-webui-pvc}"

echo "=== PVC Migration Script: RWO -> RWX ==="
echo "Namespace: ${NAMESPACE}"
echo "PVC Name: ${PVC_NAME}"
echo ""

# Check if PVC exists
if ! kubectl get pvc "${PVC_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo "PVC '${PVC_NAME}' not found. Nothing to migrate."
    exit 0
fi

# Get current access mode
CURRENT_ACCESS_MODE=$(kubectl get pvc "${PVC_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.accessModes[0]}')
echo "Current PVC access mode: ${CURRENT_ACCESS_MODE}"

if [ "${CURRENT_ACCESS_MODE}" = "ReadWriteMany" ]; then
    echo "PVC already has ReadWriteMany access mode. No migration needed."
    exit 0
fi

echo ""
echo "WARNING: This will delete the PVC and all data in it!"
echo "Make sure you have a backup before proceeding."
echo ""
read -p "Do you want to continue? (yes/no): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Scale down deployment
echo ""
echo "Step 1: Scaling down deployment..."
if kubectl get deployment open-webui -n "${NAMESPACE}" >/dev/null 2>&1; then
    kubectl scale deployment open-webui -n "${NAMESPACE}" --replicas=0
    echo "Waiting for pods to terminate..."
    sleep 10
    
    # Wait for all pods to terminate
    while kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=open-webui --no-headers 2>/dev/null | grep -v "No resources" | grep -q .; do
        echo "Still waiting for pods to terminate..."
        sleep 5
    done
    echo "All pods terminated."
else
    echo "Deployment not found, skipping scale down."
fi

# Delete PVC
echo ""
echo "Step 2: Deleting old PVC..."
kubectl delete pvc "${PVC_NAME}" -n "${NAMESPACE}" --wait=true || {
    echo "Error: Failed to delete PVC. Trying to find and delete pods using it..."
    
    # Find pods using the PVC
    kubectl get pods -n "${NAMESPACE}" -o json | jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim?.claimName=="'${PVC_NAME}'") | .metadata.name' | while read pod; do
        if [ -n "${pod}" ]; then
            echo "Force deleting pod ${pod}..."
            kubectl delete pod "${pod}" -n "${NAMESPACE}" --force --grace-period=0 2>/dev/null || true
        fi
    done
    
    sleep 5
    kubectl delete pvc "${PVC_NAME}" -n "${NAMESPACE}" --wait=true || {
        echo "Error: Could not delete PVC. Manual intervention required."
        exit 1
    }
}

echo ""
echo "PVC deleted successfully!"
echo ""
echo "Next steps:"
echo "1. Make sure values.yaml.example has accessMode: ReadWriteMany"
echo "2. Redeploy using: ./scripts/deploy-to-k8s.sh"
echo "3. Or trigger GitHub Actions workflow"
echo ""
echo "Note: Data will be restored from backup automatically via initContainer if restoreOnDeploy is enabled."

