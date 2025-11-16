#!/bin/bash
# Script to get GCP secrets for GitHub Actions
# This script helps you get the required secrets from your GCP project

set -e

PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
SERVICE_ACCOUNT_NAME="github-actions-deploy"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Getting GCP secrets for GitHub Actions"
echo "=========================================="
echo ""

# Get Project ID
if [ -z "$PROJECT_ID" ]; then
    echo "Error: No GCP project configured"
    echo "   Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo "Project ID found: $PROJECT_ID"
echo ""

# Check if Service Account exists
echo "Checking for Service Account: $SERVICE_ACCOUNT_NAME"
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
    echo "Service Account exists: $SERVICE_ACCOUNT_EMAIL"
    EXISTS=true
else
    echo "Warning: Service Account not found"
    echo "   Creating new Service Account..."
    EXISTS=false
fi

# Create Service Account if it doesn't exist
if [ "$EXISTS" = false ]; then
    echo ""
    echo "Creating Service Account..."
    gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
        --display-name="GitHub Actions Deploy" \
        --description="Service account for GitHub Actions deployment" \
        --project="$PROJECT_ID"
    
    echo "Service Account created"
fi

# Grant required roles
echo ""
echo "Granting required roles..."
ROLES=(
    "roles/container.admin"           # Kubernetes Engine Admin
    "roles/compute.admin"             # Compute Admin
    "roles/storage.admin"             # Storage Admin
    "roles/iam.serviceAccountUser"    # Service Account User
)

for ROLE in "${ROLES[@]}"; do
    echo "   Granting: $ROLE"
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
        --role="$ROLE" \
        --condition=None \
        --quiet 2>/dev/null || echo "     (already granted or failed)"
done

echo "Roles granted"
echo ""

# Create or get key
KEY_FILE="gcp-sa-key-${PROJECT_ID}.json"
if [ -f "$KEY_FILE" ]; then
    echo "Warning: Key file already exists: $KEY_FILE"
    read -p "   Do you want to create a new key? (yes/no): " CREATE_NEW
    if [ "$CREATE_NEW" != "yes" ]; then
        echo "   Using existing key file"
    else
        echo "   Creating new key..."
        gcloud iam service-accounts keys create "$KEY_FILE" \
            --iam-account="$SERVICE_ACCOUNT_EMAIL" \
            --project="$PROJECT_ID"
        echo "New key created"
    fi
else
    echo "Creating Service Account key..."
    gcloud iam service-accounts keys create "$KEY_FILE" \
        --iam-account="$SERVICE_ACCOUNT_EMAIL" \
        --project="$PROJECT_ID"
    echo "Key created: $KEY_FILE"
fi

# Display secrets
echo ""
echo "=========================================="
echo "GITHUB SECRETS - COPY THESE VALUES"
echo "=========================================="
echo ""
echo "1. GCP_PROJECT_ID:"
echo "   $PROJECT_ID"
echo ""
echo "2. GCP_SA_KEY:"
echo "   (Content of $KEY_FILE)"
echo "   File location: $(pwd)/$KEY_FILE"
echo ""
echo "3. (Optional) OPENROUTER_API_KEY:"
echo "   Get it from: https://openrouter.ai/keys"
echo ""
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Go to GitHub → Settings → Secrets → Actions"
echo "2. Add secret: GCP_PROJECT_ID = $PROJECT_ID"
echo "3. Add secret: GCP_SA_KEY = (content of $KEY_FILE)"
echo "4. (Optional) Add secret: OPENROUTER_API_KEY = (your OpenRouter key)"
echo ""
echo "  Important: Keep $KEY_FILE safe and don't commit it to Git!"
echo "   It's already in .gitignore"
echo ""

