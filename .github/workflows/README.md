# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automated deployment, backup, and restore of Open WebUI on GKE.

## 🔐 Required Secrets

**Only 2 secrets required!** Configure these in your GitHub repository settings (Settings → Secrets and variables → Actions):

### Required Secrets (Minimum - 2 secrets)

- `GCP_PROJECT_ID` - Your Google Cloud Project ID (Required)
- `GCP_SA_KEY` - Service Account JSON key with required permissions (Required)

### Optional Secret (For 344+ AI models)

- `OPENROUTER_API_KEY` - OpenRouter API key (Optional - add to enable 344+ AI models)

### Default Values (No secrets needed)

All other settings use default values:
- `GCP_REGION`: `europe-west1`
- `GCP_ZONE`: `europe-west1-b`
- `CLUSTER_NAME`: `open-webui-cluster`
- `BACKUP_BUCKET`: `open-webui-backups`
- `WEBUI_SECRET_KEY`: Auto-generated in workflow

### Service Account Permissions

The service account needs these roles:
- `Kubernetes Engine Admin`
- `Compute Admin`
- `Storage Admin` (for GCS backups)
- `Service Account User`

## 📋 Workflows

### 1. `deploy.yml` - Deploy Infrastructure and Application

**Triggers:**
- Push to `main` branch (terraform/helm changes)

**What it does:**
1. **Terraform Apply** - Creates/updates GKE cluster and infrastructure
2. **Install NGINX Ingress** - Installs ingress controller with static IP
3. **Install cert-manager** - Sets up SSL certificate management
4. **Deploy Open WebUI** - Deploys application using Helm
5. **Restore Database** - Automatically restores database from GCS backup (if exists)

**Use case:** Automated deployment when code is pushed to main branch

### 2. `destroy.yml` - Destroy Infrastructure (with Backup)

**Triggers:**
- Manual workflow dispatch only

**What it does:**
1. **Backup Database** - Creates backup of database and uploads to GCS
2. **Terraform Destroy** - Destroys infrastructure and cluster

**Use case:** Manual destruction of infrastructure (saves costs)

## 🚀 Usage

### Automated Deployment

The `deploy.yml` workflow runs automatically:
- **On push to main** - Deploys infrastructure and application
- Database is automatically restored from GCS backup (if exists)
- Static IP is preserved (configured in Terraform)

### Manual Destruction

1. Go to **Actions** tab in GitHub
2. Select **Destroy Infrastructure**
3. Click **Run workflow**
4. Workflow will:
   - Backup database to GCS
   - Destroy infrastructure

## 🔧 Configuration

### Static IP

The static IP is configured in `terraform/main.tf` with `prevent_destroy = true`, so it persists even after cluster deletion.

### Backup Storage

Backups are stored in:
- **GCS**: `gs://<BACKUP_BUCKET>/latest.db` (latest)
- **GCS**: `gs://<BACKUP_BUCKET>/backups/webui_backup_*.db` (historical)
- **GitHub Artifacts**: Available for 30 days (from destroy workflow)

### Database Restore

The deploy workflow automatically:
1. Downloads latest backup from GCS
2. Stops the pod
3. Restores database to PVC
4. Starts the pod

## 📊 Workflow Status

Monitor workflow runs in the **Actions** tab:
- ✅ Green - Success
- ⚠️ Yellow - Warning (backup not found, etc.)
- ❌ Red - Error

## 🔍 Troubleshooting

### Workflow fails: "Cluster does not exist"
- Normal on first run
- Workflow will create new cluster

### Backup fails: "Pod not found"
- Normal if cluster was just created
- Database will be empty on first deploy

### Restore fails: "No backup found"
- Normal on first deployment
- New users will be created from scratch

### Static IP not found
- Check Terraform state
- IP should persist even after destroy
- Verify `prevent_destroy = true` in `terraform/main.tf`

## 💡 Best Practices

1. **Monitor backups**: Check GCS bucket regularly
2. **Test restore**: Periodically test restore process
3. **Keep secrets secure**: Never commit secrets to repository
4. **Review logs**: Check workflow logs for issues
5. **Cost monitoring**: Monitor GCP costs for unexpected charges

## 🔐 Security

- All secrets are stored in GitHub Secrets
- Service account has minimal required permissions
- Backups are encrypted in GCS
- Database backups contain sensitive data - keep secure
