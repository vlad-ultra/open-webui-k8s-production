#!/bin/bash
# Setup GCS bucket for backups
# This script creates a GCS bucket for storing database backups

set -e

PROJECT_ID="${GCP_PROJECT_ID:-}"
BUCKET_NAME="${BACKUP_BUCKET:-open-webui-backups}"
REGION="${GCP_REGION:-europe-west1}"

if [ -z "${PROJECT_ID}" ]; then
    echo " Error: GCP_PROJECT_ID not set"
    echo "Usage: GCP_PROJECT_ID=your-project-id ./setup-gcs-backup.sh"
    exit 1
fi

echo "🔧 Setting up GCS bucket for backups..."
echo "   Project: ${PROJECT_ID}"
echo "   Bucket: ${BUCKET_NAME}"
echo "   Region: ${REGION}"

# Create bucket
echo "📦 Creating GCS bucket..."
gsutil mb -p "${PROJECT_ID}" -l "${REGION}" "gs://${BUCKET_NAME}" 2>/dev/null || {
    if [ $? -eq 1 ]; then
        echo "  Bucket already exists, continuing..."
    else
        echo " Error: Failed to create bucket"
        exit 1
    fi
}

# Set lifecycle policy (keep backups for 90 days)
echo "⚙️  Setting lifecycle policy..."
cat <<EOF > /tmp/lifecycle.json
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 90,
          "matchesPrefix": ["backups/"]
        }
      }
    ]
  }
}
EOF

gsutil lifecycle set /tmp/lifecycle.json "gs://${BUCKET_NAME}"

# Set versioning (optional, for extra safety)
echo "📚 Enabling versioning..."
gsutil versioning set on "gs://${BUCKET_NAME}"

# Set uniform bucket-level access
echo " Setting uniform bucket-level access..."
gsutil uniformbucketlevelaccess set on "gs://${BUCKET_NAME}"

echo " GCS bucket setup complete!"
echo ""
echo " Add this to your GitHub Secrets:"
echo "   BACKUP_BUCKET=${BUCKET_NAME}"
echo ""
echo " Bucket details:"
gsutil ls -L "gs://${BUCKET_NAME}"

