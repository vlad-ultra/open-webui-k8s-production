#!/bin/bash
# Create self-signed SSL certificate for domain
# Usage: ./scripts/create-self-signed-cert.sh ai-k8s.svdevops.tech
# Certificates are saved in GCS bucket and reused on subsequent deployments

set -e

DOMAIN="${1:-ai.svdevops.tech}"
NAMESPACE="${2:-ai}"
SECRET_NAME="open-webui-tls"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CERTS_DIR="${PROJECT_ROOT}/ssl-certs"

# GCS bucket configuration
BACKUP_BUCKET="${BACKUP_BUCKET:-open-webui-backups}"
GCS_CERTS_PATH="gs://${BACKUP_BUCKET}/certs"
GCS_CERT_FILE="${GCS_CERTS_PATH}/${DOMAIN}.crt"
GCS_KEY_FILE="${GCS_CERTS_PATH}/${DOMAIN}.key"

# Local certificate files
CERT_FILE="${CERTS_DIR}/${DOMAIN}.crt"
KEY_FILE="${CERTS_DIR}/${DOMAIN}.key"

echo " Setting up SSL certificate for ${DOMAIN}..."
echo ""

# Create local certs directory
mkdir -p "${CERTS_DIR}"

# Step 1: Check GCS bucket first (priority)
echo "   Checking GCS bucket for existing certificates..."
if gsutil -q stat "${GCS_CERT_FILE}" 2>/dev/null && gsutil -q stat "${GCS_KEY_FILE}" 2>/dev/null; then
    echo "    Certificates found in GCS bucket: ${GCS_CERTS_PATH}/"
    echo "   Downloading certificates from GCS..."
    gsutil cp "${GCS_CERT_FILE}" "${CERT_FILE}"
    gsutil cp "${GCS_KEY_FILE}" "${KEY_FILE}"
    echo "    Certificates downloaded from GCS to ${CERTS_DIR}/"
    CERT_FILE_TO_USE="${CERT_FILE}"
    KEY_FILE_TO_USE="${KEY_FILE}"
# Step 2: Check local directory
elif [ -f "${CERT_FILE}" ] && [ -f "${KEY_FILE}" ]; then
    echo "   Certificates found locally in ${CERTS_DIR}/"
    echo "   Uploading certificates to GCS bucket for future use..."
    gsutil cp "${CERT_FILE}" "${GCS_CERT_FILE}" 2>/dev/null || true
    gsutil cp "${KEY_FILE}" "${GCS_KEY_FILE}" 2>/dev/null || true
    echo "    Certificates uploaded to GCS bucket"
    CERT_FILE_TO_USE="${CERT_FILE}"
    KEY_FILE_TO_USE="${KEY_FILE}"
# Step 3: Generate new certificates
else
    echo "     No certificates found, generating new ones..."
    
    # Generate private key
    echo "   Generating private key..."
    openssl genrsa -out "${KEY_FILE}" 2048

    # Generate certificate signing request
    echo "   Generating certificate signing request..."
    openssl req -new -key "${KEY_FILE}" -out "${CERTS_DIR}/${DOMAIN}.csr" \
        -subj "/CN=${DOMAIN}/O=Open WebUI"

    # Generate self-signed certificate (valid for 365 days)
    echo "   Generating self-signed certificate (valid for 365 days)..."
    openssl x509 -req -days 365 -in "${CERTS_DIR}/${DOMAIN}.csr" -signkey "${KEY_FILE}" \
        -out "${CERT_FILE}" \
        -extensions v3_req -extfile <(
            echo "[v3_req]"
            echo "keyUsage = keyEncipherment, dataEncipherment"
            echo "extendedKeyUsage = serverAuth"
            echo "subjectAltName = @alt_names"
            echo "[alt_names]"
            echo "DNS.1 = ${DOMAIN}"
        )
    
    # Clean up CSR file
    rm -f "${CERTS_DIR}/${DOMAIN}.csr"
    
    # Upload to GCS bucket
    echo "   Uploading new certificates to GCS bucket..."
    gsutil cp "${CERT_FILE}" "${GCS_CERT_FILE}" 2>/dev/null || echo "   Warning: Could not upload to GCS (will use local only)"
    gsutil cp "${KEY_FILE}" "${GCS_KEY_FILE}" 2>/dev/null || echo "   Warning: Could not upload to GCS (will use local only)"
    
    CERT_FILE_TO_USE="${CERT_FILE}"
    KEY_FILE_TO_USE="${KEY_FILE}"
    
    echo "    New certificates generated and saved to ${CERTS_DIR}/ and GCS bucket"
fi

# Create namespace if it doesn't exist
echo "   Checking if namespace ${NAMESPACE} exists..."
if ! kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "   Creating namespace ${NAMESPACE}..."
    kubectl create namespace "${NAMESPACE}" || true
    echo "    Namespace ${NAMESPACE} created"
else
    echo "    Namespace ${NAMESPACE} already exists"
fi

# Create or update Kubernetes secret (always update to ensure fresh certs from GCS)
echo "   Creating/updating Kubernetes secret: ${SECRET_NAME} in namespace ${NAMESPACE}..."
kubectl create secret tls "${SECRET_NAME}" \
    --cert="${CERT_FILE_TO_USE}" \
    --key="${KEY_FILE_TO_USE}" \
    -n "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo " ✓ SSL certificate loaded and saved to Kubernetes secret!"
echo ""
echo "Certificate details:"
echo "   Domain: ${DOMAIN}"
echo "   Secret: ${SECRET_NAME} (namespace: ${NAMESPACE})"
echo "   Source: ${CERT_FILE_TO_USE}"
echo ""
# Check if certificate is Let's Encrypt or self-signed
CERT_ISSUER=$(openssl x509 -in "${CERT_FILE_TO_USE}" -noout -issuer 2>/dev/null | sed 's/issuer= //' || echo "")
if echo "${CERT_ISSUER}" | grep -q "Let's Encrypt\|R3\|X3"; then
    echo "   Certificate type: Let's Encrypt"
elif echo "${CERT_ISSUER}" | grep -q "^/CN=${DOMAIN}"; then
    echo "   Certificate type: Self-signed"
else
    echo "   Certificate type: ${CERT_ISSUER}"
fi
echo ""
echo " Certificates loaded from:"
echo "   - GCS: ${GCS_CERTS_PATH}/"
echo "   - Local: ${CERTS_DIR}/"
echo "   They will be reused on next deployment from GCS bucket"

