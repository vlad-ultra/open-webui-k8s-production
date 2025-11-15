#!/bin/bash
# Create Service Account for specific GCP project
# Usage: ./create-sa-for-project.sh ai-cluster-478022

set -e

PROJECT_ID="${1:-ai-cluster-478022}"
SERVICE_ACCOUNT_NAME="github-actions-deploy"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🔍 Creating Service Account for project: $PROJECT_ID"
echo "=========================================="
echo ""

# Check if project exists
if ! gcloud projects describe "$PROJECT_ID" &>/dev/null; then
    echo " Error: Project $PROJECT_ID not found"
    echo "   Available projects:"
    gcloud projects list --format="value(projectId)" | head -5
    exit 1
fi

echo " Project found: $PROJECT_ID"
echo ""

# Set project
gcloud config set project "$PROJECT_ID"

# Check if Service Account exists
echo " Checking for Service Account: $SERVICE_ACCOUNT_NAME"
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
    echo " Service Account exists: $SERVICE_ACCOUNT_EMAIL"
    EXISTS=true
else
    echo "  Service Account not found"
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
    
    echo " Service Account created"
fi

# Grant required roles
echo ""
echo " Granting required roles..."
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

echo " Roles granted"
echo ""

# Create key
KEY_FILE="gcp-sa-key-${PROJECT_ID}.json"
if [ -f "$KEY_FILE" ]; then
    echo "  Key file already exists: $KEY_FILE"
    read -p "   Do you want to create a new key? (yes/no): " CREATE_NEW
    if [ "$CREATE_NEW" != "yes" ]; then
        echo "   Using existing key file"
        exit 0
    fi
fi

echo " Creating Service Account key..."
gcloud iam service-accounts keys create "$KEY_FILE" \
    --iam-account="$SERVICE_ACCOUNT_EMAIL" \
    --project="$PROJECT_ID"

echo " Key created: $KEY_FILE"
echo ""

# Display secrets
echo "=========================================="
echo "📋 GITHUB SECRETS - COPY THESE VALUES"
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
echo " Next steps:"
echo "1. Go to GitHub → Settings → Secrets → Actions"
echo "2. Add secret: GCP_PROJECT_ID = $PROJECT_ID"
echo "3. Add secret: GCP_SA_KEY = (content of $KEY_FILE)"
echo "4. (Optional) Add secret: OPENROUTER_API_KEY = (your OpenRouter key)"
echo ""
echo "  Important: Keep $KEY_FILE safe and don't commit it to Git!"
echo "   It's already in .gitignore"
echo ""

